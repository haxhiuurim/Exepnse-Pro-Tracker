<?php

declare(strict_types=1);

/**
 * Load key=value pairs from a .env file into $_ENV.
 */
function loadEnv(string $path): void
{
    if (!is_readable($path)) {
        return;
    }

    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines === false) {
        return;
    }

    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        $parts = explode('=', $line, 2);
        if (count($parts) !== 2) {
            continue;
        }

        [$key, $value] = $parts;
        $key = trim($key);
        $value = trim($value, " \t\n\r\0\x0B\"'");

        if ($key !== '' && !array_key_exists($key, $_ENV)) {
            $_ENV[$key] = $value;
            putenv("$key=$value");
        }
    }
}

loadEnv(__DIR__ . '/.env');

return [
    'app_env' => $_ENV['APP_ENV'] ?? 'production',
    'debug' => filter_var($_ENV['APP_DEBUG'] ?? false, FILTER_VALIDATE_BOOL),

    'db_driver' => strtolower($_ENV['DB_DRIVER'] ?? 'sqlite'),

    'sqlite_path' => (static function (): string {
        $path = $_ENV['SQLITE_PATH'] ?? 'storage/database.sqlite';
        if ($path !== '' && $path[0] !== '/') {
            $path = __DIR__ . '/' . ltrim($path, '/');
        }
        return $path;
    })(),

    'mysql' => [
        'host' => $_ENV['DB_HOST'] ?? '127.0.0.1',
        'port' => (int) ($_ENV['DB_PORT'] ?? 3306),
        'database' => $_ENV['DB_DATABASE'] ?? 'inpenso',
        'username' => $_ENV['DB_USERNAME'] ?? 'root',
        'password' => $_ENV['DB_PASSWORD'] ?? '',
        'charset' => $_ENV['DB_CHARSET'] ?? 'utf8mb4',
    ],

    'cors' => [
        'allowed_origins' => array_filter(array_map('trim', explode(',', $_ENV['CORS_ORIGINS'] ?? '*'))),
        'allowed_methods' => 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'allowed_headers' => 'Content-Type, Authorization, X-API-Token, X-Requested-With',
        'max_age' => 86400,
    ],
];
