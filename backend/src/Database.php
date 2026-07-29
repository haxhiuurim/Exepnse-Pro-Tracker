<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;
use PDOException;
use RuntimeException;

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
                    throw new RuntimeException('Cannot create database directory: ' . $dir);
                }
                if (!is_writable($dir)) {
                    throw new RuntimeException('Database directory is not writable: ' . $dir);
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

        try {
            self::ensureSchema(self::$connection, $driver);
        } catch (PDOException $e) {
            throw new RuntimeException('Database schema setup failed: ' . $e->getMessage(), 0, $e);
        }

        return self::$connection;
    }

    /**
     * Create tables if missing so /api/trips works after deploy without a manual migrate.
     */
    public static function ensureSchema(PDO $db, string $driver): void
    {
        if (self::tableExists($db, $driver, 'users')) {
            return;
        }

        Schema::apply($db, $driver);
    }

    private static function tableExists(PDO $db, string $driver, string $table): bool
    {
        try {
            if ($driver === 'mysql') {
                $stmt = $db->prepare(
                    'SELECT 1 FROM information_schema.tables
                     WHERE table_schema = DATABASE() AND table_name = :table LIMIT 1'
                );
                $stmt->execute(['table' => $table]);
                return (bool) $stmt->fetchColumn();
            }

            $stmt = $db->prepare(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = :table LIMIT 1"
            );
            $stmt->execute(['table' => $table]);
            return (bool) $stmt->fetchColumn();
        } catch (PDOException) {
            return false;
        }
    }

    public static function reset(): void
    {
        self::$connection = null;
    }
}
