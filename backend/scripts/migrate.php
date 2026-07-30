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
    $tables = [
        'expense_splits', 'expenses', 'trip_settlements', 'trip_join_requests',
        'trip_shortcuts', 'trip_members', 'trips', 'sync_documents',
        'admin_audit_log', 'app_config', 'devices', 'users',
    ];
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

$statements = Database::splitSqlStatements($sql);
$tables = [];
$indexes = [];
foreach ($statements as $statement) {
    if (preg_match('/^\s*CREATE\s+INDEX\b/i', $statement) === 1) {
        $indexes[] = $statement;
    } else {
        $tables[] = $statement;
    }
}

// 1) Create tables (IF NOT EXISTS — safe on existing DBs)
$tableOk = 0;
foreach ($tables as $statement) {
    try {
        $db->exec($statement);
        $tableOk++;
    } catch (Throwable $e) {
        fwrite(STDERR, 'Table step skipped: ' . $e->getMessage() . PHP_EOL);
    }
}
echo "Schema tables applied: {$tableOk}/" . count($tables) . "\n";

if (!Database::schemaReady($db, $driver)) {
    fwrite(STDERR, "Migration finished but users table is still missing.\n");
    exit(1);
}

// 2) Incremental column/table upgrades BEFORE indexes that need those columns
$upgradeFile = $driver === 'mysql'
    ? dirname(__DIR__) . '/database/upgrades.mysql.php'
    : dirname(__DIR__) . '/database/upgrades.sqlite.php';
if (is_readable($upgradeFile)) {
    /** @var list<string> $upgrades */
    $upgrades = require $upgradeFile;
    $applied = 0;
    foreach ($upgrades as $upgradeSql) {
        try {
            $db->exec($upgradeSql);
            $applied++;
        } catch (Throwable) {
            // Column/table/index may already exist.
        }
    }
    echo "Upgrades attempted: {$applied}\n";
}

// 3) Indexes last (columns now exist on upgraded DBs)
$indexOk = 0;
foreach ($indexes as $statement) {
    try {
        $db->exec($statement);
        $indexOk++;
    } catch (Throwable $e) {
        fwrite(STDERR, 'Index step skipped: ' . $e->getMessage() . PHP_EOL);
    }
}
echo "Schema indexes applied: {$indexOk}/" . count($indexes) . "\n";

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
