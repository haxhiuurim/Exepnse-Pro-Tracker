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

echo "Expense migrate\n";
echo "Driver: {$driver}\n";

// Bypass ensureSchema so --fresh can drop first.
Database::reset();

$path = $config['sqlite_path'] ?? '';
if ($driver === 'sqlite') {
    $dir = dirname($path);
    if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
        fwrite(STDERR, "Cannot create storage dir: {$dir}\n");
        exit(1);
    }
    if (!is_writable($dir)) {
        fwrite(STDERR, "Storage dir not writable: {$dir}\nMake it writable: chmod -R 775 storage\n");
        exit(1);
    }
}

try {
    // Connect without auto-schema by temporarily using raw PDO path for fresh drops.
    if ($driver === 'sqlite') {
        $db = new PDO('sqlite:' . $path, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        $db->exec('PRAGMA foreign_keys = ON');
    } else {
        $mysql = $config['mysql'];
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $mysql['host'],
            $mysql['port'],
            $mysql['database'],
            $mysql['charset']
        );
        $db = new PDO($dsn, $mysql['username'], $mysql['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Connection failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

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

$sql = file_get_contents($schemaFile);
if ($sql === false) {
    fwrite(STDERR, "Could not read schema file.\n");
    exit(1);
}

try {
    foreach (Database::splitSqlStatements($sql) as $statement) {
        $db->exec($statement);
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Migration failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

if (!Database::schemaReady($db, $driver)) {
    fwrite(STDERR, "Migration finished but users table is still missing.\n");
    exit(1);
}

echo "Migration complete.\n";
echo "Schema ready: yes\n";

if ($driver === 'mysql') {
    try {
        $db->exec('ALTER TABLE trips MODIFY invite_code VARCHAR(16) NOT NULL');
        echo "Ensured trips.invite_code is VARCHAR(16).\n";
    } catch (Throwable $e) {
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
    echo 'Database file: ' . $path . PHP_EOL;
    echo "Tip: ensure the web user can write this file (chmod -R 775 storage).\n";
}
