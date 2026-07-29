<?php

declare(strict_types=1);

/**
 * Run database migrations.
 *
 * Usage:
 *   php scripts/migrate.php
 *   php scripts/migrate.php --fresh   # drop all tables first (SQLite only)
 */

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

use Inpenso\Database;

$driver = $config['db_driver'] ?? 'sqlite';
$fresh = in_array('--fresh', $argv ?? [], true);

echo "Inpenso migrate\n";
echo "Driver: {$driver}\n";

$db = Database::connection($config);

if ($fresh && $driver === 'sqlite') {
    echo "Dropping existing SQLite tables...\n";
    $tables = ['expense_splits', 'expenses', 'trip_members', 'trips', 'users'];
    foreach ($tables as $table) {
        $db->exec("DROP TABLE IF EXISTS {$table}");
    }
}

$schemaFile = $driver === 'mysql'
    ? dirname(__DIR__) . '/database/schema.mysql.sql'
    : dirname(__DIR__) . '/database/schema.sql';

if (!is_readable($schemaFile)) {
    fwrite(STDERR, "Schema file not found: {$schemaFile}\n");
    exit(1);
}

try {
    \Inpenso\Schema::apply($db, $driver);
} catch (Throwable $e) {
    fwrite(STDERR, 'Migration failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

echo "Migration complete.\n";

if ($driver === 'mysql') {
    try {
        $db->exec('ALTER TABLE trips MODIFY invite_code VARCHAR(16) NOT NULL');
        echo "Ensured trips.invite_code is VARCHAR(16).\n";
    } catch (Throwable $e) {
        // Column may already be correct on fresh installs.
        echo "invite_code column check skipped: " . $e->getMessage() . PHP_EOL;
    }
}

$rateDir = dirname(__DIR__) . '/storage/rate_limits';
if (!is_dir($rateDir) && !mkdir($rateDir, 0755, true) && !is_dir($rateDir)) {
    fwrite(STDERR, "Warning: could not create {$rateDir}\n");
} else {
    echo "Rate limit storage ready: {$rateDir}\n";
}

if ($driver === 'sqlite') {
    echo 'Database file: ' . $config['sqlite_path'] . PHP_EOL;
}
