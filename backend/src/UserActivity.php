<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;

final class UserActivity
{
    public static function isPremium(?array $user): bool
    {
        if ($user === null) {
            return false;
        }
        $until = $user['premium_until'] ?? null;
        if ($until === null || $until === '') {
            return false;
        }
        if (is_numeric($until)) {
            return (int) $until >= time();
        }
        $untilStr = trim((string) $until);
        if ($untilStr === '' || strcasecmp($untilStr, 'null') === 0) {
            return false;
        }
        // Lifetime / far-future grants
        if (str_starts_with($untilStr, '9999')) {
            return true;
        }
        $ts = strtotime($untilStr . ' UTC');
        if ($ts === false) {
            $ts = strtotime($untilStr);
        }
        if ($ts === false) {
            // Fall back to lexicographic compare for Y-m-d H:i:s
            return $untilStr >= gmdate('Y-m-d H:i:s');
        }
        return $ts >= time();
    }

    /** Reload a user row (fresh premium_until after admin grants). */
    public static function fetchUser(PDO $db, int $userId): ?array
    {
        $stmt = $db->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $userId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function touchSeen(PDO $db, int $userId, array $meta = []): void
    {
        $fields = ['last_seen_at = :seen', 'updated_at = :seen'];
        $params = ['seen' => gmdate('Y-m-d H:i:s'), 'id' => $userId];
        foreach (['app_version', 'ios_version', 'device_model'] as $key) {
            if (!empty($meta[$key])) {
                $fields[] = "{$key} = :{$key}";
                $params[$key] = substr((string) $meta[$key], 0, 128);
            }
        }
        $sql = 'UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = :id';
        $db->prepare($sql)->execute($params);
    }

    public static function touchData(PDO $db, int $userId): void
    {
        $now = gmdate('Y-m-d H:i:s');
        $db->prepare(
            'UPDATE users SET last_data_at = :t, last_seen_at = :t, updated_at = :t WHERE id = :id'
        )->execute(['t' => $now, 'id' => $userId]);
    }

    public static function upsertDevice(PDO $db, array $payload, ?int $userId): array
    {
        $uuid = trim((string) ($payload['device_uuid'] ?? ''));
        if ($uuid === '' || strlen($uuid) > 64) {
            Response::error('device_uuid is required', 422);
        }

        $now = gmdate('Y-m-d H:i:s');
        $stmt = $db->prepare('SELECT * FROM devices WHERE device_uuid = :u LIMIT 1');
        $stmt->execute(['u' => $uuid]);
        $existing = $stmt->fetch();

        $fields = [
            'last_seen_at' => $now,
            'app_version' => self::nullableStr($payload['app_version'] ?? null, 32),
            'ios_version' => self::nullableStr($payload['ios_version'] ?? null, 32),
            'device_model' => self::nullableStr($payload['device_model'] ?? null, 128),
            'locale' => self::nullableStr($payload['locale'] ?? null, 32),
            'timezone' => self::nullableStr($payload['timezone'] ?? null, 64),
            'push_token' => self::nullableStr($payload['push_token'] ?? null, 255),
            'is_guest' => $userId === null ? 1 : 0,
            'user_id' => $userId,
        ];

        if (!empty($payload['mark_data_change'])) {
            $fields['last_data_at'] = $now;
        }

        if ($existing) {
            // Don't unlink an existing user unless a new user is provided.
            if ($userId === null && !empty($existing['user_id'])) {
                $fields['user_id'] = (int) $existing['user_id'];
                $fields['is_guest'] = 0;
            }
            $sets = [];
            $params = ['id' => (int) $existing['id']];
            foreach ($fields as $k => $v) {
                if ($v === null && in_array($k, ['app_version', 'ios_version', 'device_model', 'locale', 'timezone', 'push_token'], true)) {
                    continue;
                }
                $sets[] = "{$k} = :{$k}";
                $params[$k] = $v;
            }
            $db->prepare('UPDATE devices SET ' . implode(', ', $sets) . ' WHERE id = :id')->execute($params);
            $stmt->execute(['u' => $uuid]);
            return $stmt->fetch() ?: $existing;
        }

        $ins = $db->prepare(
            'INSERT INTO devices (
                device_uuid, user_id, is_guest, first_seen_at, last_seen_at, last_data_at,
                app_version, ios_version, device_model, locale, timezone, push_token
             ) VALUES (
                :device_uuid, :user_id, :is_guest, :first_seen_at, :last_seen_at, :last_data_at,
                :app_version, :ios_version, :device_model, :locale, :timezone, :push_token
             )'
        );
        $ins->execute([
            'device_uuid' => $uuid,
            'user_id' => $userId,
            'is_guest' => $userId === null ? 1 : 0,
            'first_seen_at' => $now,
            'last_seen_at' => $now,
            'last_data_at' => !empty($payload['mark_data_change']) ? $now : null,
            'app_version' => $fields['app_version'],
            'ios_version' => $fields['ios_version'],
            'device_model' => $fields['device_model'],
            'locale' => $fields['locale'],
            'timezone' => $fields['timezone'],
            'push_token' => $fields['push_token'],
        ]);

        $stmt->execute(['u' => $uuid]);
        return $stmt->fetch() ?: [];
    }

    public static function audit(
        PDO $db,
        int $adminId,
        string $action,
        ?string $targetType = null,
        ?string $targetId = null,
        mixed $details = null
    ): void {
        $db->prepare(
            'INSERT INTO admin_audit_log (admin_user_id, action, target_type, target_id, details, ip_address, created_at)
             VALUES (:admin, :action, :tt, :tid, :details, :ip, :created)'
        )->execute([
            'admin' => $adminId,
            'action' => $action,
            'tt' => $targetType,
            'tid' => $targetId,
            'details' => is_string($details) ? $details : json_encode($details, JSON_UNESCAPED_UNICODE),
            'ip' => $_SERVER['REMOTE_ADDR'] ?? null,
            'created' => gmdate('Y-m-d H:i:s'),
        ]);
    }

    private static function nullableStr(mixed $value, int $max): ?string
    {
        if ($value === null) {
            return null;
        }
        $s = trim((string) $value);
        if ($s === '') {
            return null;
        }
        return mb_substr($s, 0, $max);
    }
}
