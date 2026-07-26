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
                if (!is_dir($dir)) {
                    mkdir($dir, 0755, true);
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

        return self::$connection;
    }

    public static function reset(): void
    {
        self::$connection = null;
    }
}
