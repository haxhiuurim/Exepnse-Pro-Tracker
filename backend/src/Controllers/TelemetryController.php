<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\AppConfig;
use Inpenso\Auth;
use Inpenso\Response;
use Inpenso\UserActivity;
use PDO;

final class TelemetryController
{
    public function __construct(private PDO $db)
    {
    }

    public function heartbeat(): void
    {
        $body = Response::readJsonBody();
        $user = Auth::authenticate($this->db);
        $userId = $user ? (int) $user['id'] : null;
        $banned = $user && (int) ($user['is_banned'] ?? 0) === 1;

        // Still accept heartbeat when banned so the app can show a lock screen.
        $device = UserActivity::upsertDevice($this->db, $body, $banned ? null : $userId);

        if ($userId !== null && !$banned) {
            UserActivity::touchSeen($this->db, $userId, [
                'app_version' => $body['app_version'] ?? null,
                'ios_version' => $body['ios_version'] ?? null,
                'device_model' => $body['device_model'] ?? null,
            ]);
            if (!empty($body['mark_data_change'])) {
                UserActivity::touchData($this->db, $userId);
            }
            // Re-read so admin premium grants are reflected immediately.
            $user = UserActivity::fetchUser($this->db, $userId) ?? $user;
        }

        Response::success([
            'device_id' => (int) ($device['id'] ?? 0),
            'device_uuid' => $device['device_uuid'] ?? ($body['device_uuid'] ?? null),
            'premium' => $banned ? false : UserActivity::isPremium($user),
            'premium_until' => $banned ? null : ($user['premium_until'] ?? null),
            'user_id' => $userId,
            'banned' => $banned,
            'banned_message' => $banned
                ? 'This account has been suspended. Contact support if you believe this is a mistake.'
                : null,
            'config' => AppConfig::publicPayload($this->db),
        ]);
    }
}
