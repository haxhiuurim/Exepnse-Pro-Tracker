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

try {
    $db = Database::connection($config);
} catch (Throwable $e) {
    Response::error($config['debug'] ? $e->getMessage() : 'Service unavailable', 503);
}

$authController = new AuthController($db);
$tripController = new TripController($db);
$expenseController = new ExpenseController($db);

$router = new Router();

$router->get('/api/health', static function () use ($config): void {
    Response::success([
        'status' => 'ok',
        'time' => gmdate('c'),
        'driver' => $config['db_driver'] ?? 'sqlite',
    ]);
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

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = $_SERVER['REQUEST_URI'] ?? '/';

try {
    $router->dispatch($method, $uri);
} catch (Throwable $e) {
    if ($config['debug']) {
        Response::error($e->getMessage(), 500);
    }

    Response::error('Internal server error', 500);
}
