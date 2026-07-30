<?php

declare(strict_types=1);

use Inpenso\Controllers\AdminController;
use Inpenso\Controllers\AuthController;
use Inpenso\Controllers\ConfigController;
use Inpenso\Controllers\ExpenseController;
use Inpenso\Controllers\SyncController;
use Inpenso\Controllers\TelemetryController;
use Inpenso\Controllers\TripController;
use Inpenso\Database;
use Inpenso\Response;
use Inpenso\Router;

$config = require dirname(__DIR__) . '/config.php';

spl_autoload_register(static function (string $class): void {
    $prefix = 'Inpenso\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = dirname(__DIR__) . '/src/' . str_replace('\\', '/', $relative) . '.php';

    if (is_readable($path)) {
        require $path;
    }
});

Response::applyCors($config['cors']);

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($uri, PHP_URL_PATH) ?: '/';
$path = rtrim($path, '/') ?: '/';

if ($method === 'GET' && $path === '/') {
    require __DIR__ . '/landing.php';
    exit;
}

if ($method === 'GET' && ($path === '/admin' || $path === '/admin/')) {
    require __DIR__ . '/admin.php';
    exit;
}

try {
    $db = Database::connection($config);
} catch (Throwable $e) {
    Response::error($e->getMessage(), 503);
}

$authController = new AuthController($db);
$tripController = new TripController($db);
$expenseController = new ExpenseController($db);
$syncController = new SyncController($db);
$configController = new ConfigController($db);
$telemetryController = new TelemetryController($db);
$adminController = new AdminController($db);

$router = new Router();

$router->get('/api/health', static function () use ($config, $db): void {
    $driver = $config['db_driver'] ?? 'sqlite';
    $ready = Database::schemaReady($db, $driver);
    Response::success([
        'status' => $ready ? 'ok' : 'needs_migration',
        'time' => gmdate('c'),
        'driver' => $driver,
        'schema_ready' => $ready,
    ], $ready ? 200 : 503);
});

$router->get('/api/config', static function () use ($configController): void {
    $configController->publicConfig();
});
$router->post('/api/telemetry/heartbeat', static function () use ($telemetryController): void {
    $telemetryController->heartbeat();
});

$router->post('/api/auth/register', static function () use ($authController): void {
    $authController->register();
});
$router->post('/api/auth/login', static function () use ($authController): void {
    $authController->login();
});
$router->get('/api/auth/me', static function () use ($authController): void {
    $authController->me();
});
$router->post('/api/auth/logout', static function () use ($authController): void {
    $authController->logout();
});

$router->get('/api/sync', static function () use ($syncController): void {
    $syncController->pull();
});
$router->put('/api/sync', static function () use ($syncController): void {
    $syncController->push();
});
$router->post('/api/sync', static function () use ($syncController): void {
    $syncController->push();
});

$router->post('/api/trips', static function () use ($tripController): void {
    $tripController->create();
});
$router->post('/api/trips/join', static function () use ($tripController): void {
    $tripController->join();
});
$router->get('/api/trips', static function () use ($tripController): void {
    $tripController->list();
});
$router->get('/api/trips/{id}', static function (string $id) use ($tripController): void {
    $tripController->show($id);
});
$router->post('/api/trips/{id}/leave', static function (string $id) use ($tripController): void {
    $tripController->leave($id);
});
$router->delete('/api/trips/{id}', static function (string $id) use ($tripController): void {
    $tripController->delete($id);
});
$router->get('/api/trips/{id}/join-requests', static function (string $id) use ($tripController): void {
    $tripController->listJoinRequests($id);
});
$router->post('/api/trips/{id}/join-requests/{requestId}/accept', static function (string $id, string $requestId) use ($tripController): void {
    $tripController->acceptJoinRequest($id, $requestId);
});
$router->post('/api/trips/{id}/join-requests/{requestId}/decline', static function (string $id, string $requestId) use ($tripController): void {
    $tripController->declineJoinRequest($id, $requestId);
});

$router->get('/api/trips/{id}/expenses', static function (string $id) use ($expenseController): void {
    $expenseController->list($id);
});
$router->post('/api/trips/{id}/expenses', static function (string $id) use ($expenseController): void {
    $expenseController->create($id);
});
$router->delete('/api/trips/{id}/expenses/{expenseId}', static function (string $id, string $expenseId) use ($expenseController): void {
    $expenseController->delete($id, $expenseId);
});

// ——— Admin API ———
$router->get('/api/admin/dashboard', static function () use ($adminController): void {
    $adminController->dashboard();
});
$router->get('/api/admin/users', static function () use ($adminController): void {
    $adminController->listUsers();
});
$router->get('/api/admin/users/{id}', static function (string $id) use ($adminController): void {
    $adminController->showUser($id);
});
$router->patch('/api/admin/users/{id}', static function (string $id) use ($adminController): void {
    $adminController->updateUser($id);
});
$router->post('/api/admin/users/{id}/premium', static function (string $id) use ($adminController): void {
    $adminController->grantPremium($id);
});
$router->delete('/api/admin/users/{id}/premium', static function (string $id) use ($adminController): void {
    $adminController->revokePremium($id);
});
$router->delete('/api/admin/users/{id}', static function (string $id) use ($adminController): void {
    $adminController->deleteUser($id);
});
$router->get('/api/admin/devices', static function () use ($adminController): void {
    $adminController->listDevices();
});
$router->get('/api/admin/config', static function () use ($adminController): void {
    $adminController->getConfig();
});
$router->put('/api/admin/config', static function () use ($adminController): void {
    $adminController->updateConfig();
});
$router->get('/api/admin/trips', static function () use ($adminController): void {
    $adminController->listTrips();
});
$router->get('/api/admin/audit', static function () use ($adminController): void {
    $adminController->listAudit();
});

try {
    $router->dispatch($method, $uri);
} catch (Throwable $e) {
    $message = $e->getMessage();
    $isSchema = str_contains(strtolower($message), 'no such table')
        || str_contains(strtolower($message), "doesn't exist")
        || str_contains(strtolower($message), 'base table or view not found')
        || str_contains(strtolower($message), 'no such column');

    if ($config['debug'] || $isSchema) {
        Response::error(
            $isSchema
                ? 'Database not migrated. SSH to the server and run: php scripts/migrate.php && php scripts/seed_admin.php'
                : $message,
            500
        );
    }

    Response::error('Internal server error', 500);
}
