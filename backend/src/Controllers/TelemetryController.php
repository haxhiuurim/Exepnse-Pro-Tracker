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

        if ($user && (int) ($user['is_banned'] ?? 0) === 1) {
            Response::error('This account has been suspended.', 403);
        }

        $device = UserActivity::upsertDevice($this->db, $body, $userId);

        if ($userId !== null) {
            UserActivity::touchSeen($this->db, $userId, [
                'app_version' => $body['app_version'] ?? null,
                'ios_version' => $body['ios_version'] ?? null,
                'device_model' => $body['device_model'] ?? null,
            ]);
            if (!empty($body['mark_data_change'])) {
                UserActivity::touchData($this->db, $userId);
            }
        }

        Response::success([
            'device_id' => (int) ($device['id'] ?? 0),
            'device_uuid' => $device['device_uuid'] ?? ($body['device_uuid'] ?? null),
            'premium' => UserActivity::isPremium($user),
            'premium_until' => $user['premium_until'] ?? null,
            'banned' => false,
            'config' => AppConfig::publicPayload($this->db),
        ]);
    }
}
