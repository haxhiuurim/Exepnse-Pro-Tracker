<?php

declare(strict_types=1);

use Inpenso\Controllers\AuthController;
use Inpenso\Controllers\ExpenseController;
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

try {
    $db = Database::connection($config);
} catch (Throwable $e) {
    // Permission / migrate issues should stay visible so hosts can fix them quickly.
    Response::error($e->getMessage(), 503);
}

$authController = new AuthController($db);
$tripController = new TripController($db);
$expenseController = new ExpenseController($db);

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

$router->post('/api/auth/register', static function () use ($authController): void {
    $authController->register();
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

$router->get('/api/trips/{id}/expenses', static function (string $id) use ($expenseController): void {
    $expenseController->list($id);
});

$router->post('/api/trips/{id}/expenses', static function (string $id) use ($expenseController): void {
    $expenseController->create($id);
});

$router->delete('/api/trips/{id}/expenses/{expenseId}', static function (string $id, string $expenseId) use ($expenseController): void {
    $expenseController->delete($id, $expenseId);
});

try {
    $router->dispatch($method, $uri);
} catch (Throwable $e) {
    $message = $e->getMessage();
    $isSchema = str_contains(strtolower($message), 'no such table')
        || str_contains(strtolower($message), "doesn't exist")
        || str_contains(strtolower($message), 'base table or view not found');

    if ($config['debug'] || $isSchema) {
        Response::error(
            $isSchema
                ? 'Database not migrated. SSH to the server and run: php scripts/migrate.php'
                : $message,
            500
        );
    }

    Response::error('Internal server error', 500);
}
