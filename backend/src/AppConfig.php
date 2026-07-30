<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;

final class AppConfig
{
    public const DEFAULTS = [
        'maintenance_mode' => '0',
        'maintenance_message' => 'Expense is temporarily down for maintenance. Please try again shortly.',
        'force_update' => '0',
        'min_ios_version' => '17.0',
        'min_app_version' => '1.0.0',
        'app_store_url' => 'https://apps.apple.com/app/expense/idXXXXXXXXX',
        'support_email' => 'support@usolution.cloud',
        'announcement_active' => '0',
        'announcement_title' => '',
        'announcement_message' => '',
        'feature_trips_enabled' => '1',
        'feature_sync_enabled' => '1',
        'feature_registration_enabled' => '1',
        'feature_receipt_scan_enabled' => '1',
    ];

    public static function all(PDO $db): array
    {
        self::ensureDefaults($db);
        $rows = $db->query('SELECT config_key, config_value, updated_at FROM app_config')->fetchAll();
        $out = [];
        foreach ($rows as $row) {
            $out[$row['config_key']] = [
                'value' => $row['config_value'],
                'updated_at' => $row['updated_at'],
            ];
        }
        foreach (self::DEFAULTS as $key => $value) {
            if (!isset($out[$key])) {
                $out[$key] = ['value' => $value, 'updated_at' => null];
            }
        }
        return $out;
    }

    public static function publicPayload(PDO $db): array
    {
        $all = self::all($db);
        $get = static fn (string $key): string => (string) ($all[$key]['value'] ?? self::DEFAULTS[$key] ?? '');

        return [
            'maintenance_mode' => $get('maintenance_mode') === '1',
            'maintenance_message' => $get('maintenance_message'),
            'force_update' => $get('force_update') === '1',
            'min_ios_version' => $get('min_ios_version'),
            'min_app_version' => $get('min_app_version'),
            'app_store_url' => $get('app_store_url'),
            'support_email' => $get('support_email'),
            'announcement' => [
                'active' => $get('announcement_active') === '1',
                'title' => $get('announcement_title'),
                'message' => $get('announcement_message'),
            ],
            'features' => [
                'trips' => $get('feature_trips_enabled') === '1',
                'sync' => $get('feature_sync_enabled') === '1',
                'registration' => $get('feature_registration_enabled') === '1',
                'receipt_scan' => $get('feature_receipt_scan_enabled') === '1',
            ],
            'server_time' => gmdate('c'),
        ];
    }

    public static function set(PDO $db, string $key, string $value, ?int $adminId = null): void
    {
        if (!array_key_exists($key, self::DEFAULTS)) {
            Response::error('Unknown config key: ' . $key, 422);
        }
        $now = gmdate('Y-m-d H:i:s');
        try {
            $stmt = $db->prepare(
                'INSERT INTO app_config (config_key, config_value, updated_at, updated_by)
                 VALUES (:k, :v, :u, :by)
                 ON CONFLICT(config_key) DO UPDATE SET
                    config_value = excluded.config_value,
                    updated_at = excluded.updated_at,
                    updated_by = excluded.updated_by'
            );
            $stmt->execute(['k' => $key, 'v' => $value, 'u' => $now, 'by' => $adminId]);
        } catch (\PDOException) {
            $stmt = $db->prepare(
                'INSERT INTO app_config (config_key, config_value, updated_at, updated_by)
                 VALUES (:k, :v, :u, :by)
                 ON DUPLICATE KEY UPDATE
                    config_value = VALUES(config_value),
                    updated_at = VALUES(updated_at),
                    updated_by = VALUES(updated_by)'
            );
            $stmt->execute(['k' => $key, 'v' => $value, 'u' => $now, 'by' => $adminId]);
        }
    }

    public static function ensureDefaults(PDO $db): void
    {
        foreach (self::DEFAULTS as $key => $value) {
            $check = $db->prepare('SELECT 1 FROM app_config WHERE config_key = :k LIMIT 1');
            $check->execute(['k' => $key]);
            if (!$check->fetch()) {
                $ins = $db->prepare(
                    'INSERT INTO app_config (config_key, config_value, updated_at) VALUES (:k, :v, :u)'
                );
                try {
                    $ins->execute(['k' => $key, 'v' => $value, 'u' => gmdate('Y-m-d H:i:s')]);
                } catch (\PDOException) {
                    // race
                }
            }
        }
    }
}
