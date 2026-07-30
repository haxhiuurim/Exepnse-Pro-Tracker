<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;
use PDOException;
use RuntimeException;
use Throwable;

final class Database
{
    private static ?PDO $connection = null;

    public static function connection(array $config): PDO
    {
        if (self::$connection instanceof PDO) {
            return self::$connection;
        }

        $driver = $config['db_driver'] ?? 'sqlite';

        try {
            if ($driver === 'mysql') {
                $mysql = $config['mysql'];
                $dsn = sprintf(
                    'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                    $mysql['host'],
                    $mysql['port'],
                    $mysql['database'],
                    $mysql['charset']
                );
                self::$connection = new PDO($dsn, $mysql['username'], $mysql['password'], [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                ]);
            } else {
                $path = $config['sqlite_path'];
                $dir = dirname($path);
                if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                    throw new RuntimeException('Cannot create SQLite directory: ' . $dir);
                }

                if (file_exists($path) && !is_writable($path)) {
                    throw new RuntimeException(
                        'SQLite database is not writable: ' . $path
                        . ' — fix with: chown -R <web-user>:<web-user> storage && chmod -R 775 storage'
                    );
                }

                if (!file_exists($path) && !is_writable($dir)) {
                    throw new RuntimeException(
                        'SQLite directory is not writable: ' . $dir
                        . ' — fix with: chown -R <web-user>:<web-user> storage && chmod -R 775 storage'
                    );
                }

                self::$connection = new PDO('sqlite:' . $path, null, null, [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                ]);
                self::$connection->exec('PRAGMA foreign_keys = ON');
            }
        } catch (PDOException $e) {
            throw new RuntimeException('Database connection failed: ' . $e->getMessage(), 0, $e);
        }

        self::ensureSchema(self::$connection, $driver);
        self::ensureStorageDirs();

        return self::$connection;
    }

    public static function reset(): void
    {
        self::$connection = null;
    }

    public static function schemaReady(PDO $db, string $driver = 'sqlite'): bool
    {
        try {
            if ($driver === 'mysql') {
                $stmt = $db->query("SHOW TABLES LIKE 'users'");
                return (bool) $stmt?->fetchColumn();
            }

            $stmt = $db->query(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='users' LIMIT 1"
            );
            return (bool) $stmt?->fetchColumn();
        } catch (Throwable) {
            return false;
        }
    }

    public static function ensureSchema(PDO $db, string $driver = 'sqlite'): void
    {
        if (self::schemaReady($db, $driver)) {
            return;
        }

        $schemaFile = $driver === 'mysql'
            ? dirname(__DIR__) . '/database/schema.mysql.sql'
            : dirname(__DIR__) . '/database/schema.sql';

        if (!is_readable($schemaFile)) {
            throw new RuntimeException('Schema file missing: ' . $schemaFile);
        }

        $sql = file_get_contents($schemaFile);
        if ($sql === false) {
            throw new RuntimeException('Could not read schema file.');
        }

        try {
            foreach (self::splitSqlStatements($sql) as $statement) {
                $db->exec($statement);
            }
        } catch (PDOException $e) {
            throw new RuntimeException(
                'Failed to create database tables. Run: php scripts/migrate.php — ' . $e->getMessage(),
                0,
                $e
            );
        }

        if (!self::schemaReady($db, $driver)) {
            throw new RuntimeException(
                'Database tables are still missing after auto-migrate. Check storage permissions and run php scripts/migrate.php'
            );
        }
    }

    /**
     * Split a schema SQL file into executable statements.
     * Strips full-line `--` comments so header comments don't hide CREATE TABLE.
     *
     * @return list<string>
     */
    public static function splitSqlStatements(string $sql): array
    {
        $withoutLineComments = preg_replace('/^\\s*--.*$/m', '', $sql) ?? $sql;
        $chunks = explode(';', $withoutLineComments);
        $statements = [];

        foreach ($chunks as $chunk) {
            $statement = trim($chunk);
            if ($statement === '') {
                continue;
            }
            $statements[] = $statement;
        }

        return $statements;
    }

    private static function ensureStorageDirs(): void
    {
        $rateDir = dirname(__DIR__) . '/storage/rate_limits';
        if (!is_dir($rateDir)) {
            @mkdir($rateDir, 0755, true);
        }
    }
}
