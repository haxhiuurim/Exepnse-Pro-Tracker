<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;
use RuntimeException;

final class Schema
{
    public static function apply(PDO $db, string $driver): void
    {
        $schemaFile = $driver === 'mysql'
            ? dirname(__DIR__) . '/database/schema.mysql.sql'
            : dirname(__DIR__) . '/database/schema.sql';

        if (!is_readable($schemaFile)) {
            throw new RuntimeException('Database schema file is missing. Run php scripts/migrate.php');
        }

        $sql = file_get_contents($schemaFile);
        if ($sql === false) {
            throw new RuntimeException('Could not read database schema file');
        }

        foreach (self::statements($sql) as $statement) {
            $db->exec($statement);
        }
    }

    /**
     * Split SQL into executable statements, ignoring leading comment lines.
     *
     * @return list<string>
     */
    public static function statements(string $sql): array
    {
        $statements = [];

        foreach (explode(';', $sql) as $chunk) {
            $lines = preg_split('/\R/', $chunk) ?: [];
            $kept = [];

            foreach ($lines as $line) {
                $trimmed = ltrim($line);
                if ($trimmed === '' || str_starts_with($trimmed, '--')) {
                    continue;
                }
                $kept[] = $line;
            }

            $statement = trim(implode("\n", $kept));
            if ($statement !== '') {
                $statements[] = $statement;
            }
        }

        return $statements;
    }
}
