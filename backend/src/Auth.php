<?php

declare(strict_types=1);

namespace Inpenso;

use PDO;

final class Auth
{
    public static function generateToken(): string
    {
        return bin2hex(random_bytes(32));
    }

    public static function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }

    public static function extractToken(): ?string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['HTTP_X_API_TOKEN'] ?? '';

        if (str_starts_with($header, 'Bearer ')) {
            return trim(substr($header, 7));
        }

        if ($header !== '') {
            return trim($header);
        }

        return null;
    }

    public static function authenticate(PDO $db): ?array
    {
        $token = self::extractToken();
        if ($token === null || $token === '') {
            return null;
        }

        if (strlen($token) > 128) {
            return null;
        }

        $hash = self::hashToken($token);

        $stmt = $db->prepare(
            'SELECT id, display_name, email, api_token, created_at,
                    is_admin, is_banned, premium_until, premium_note,
                    last_seen_at, last_data_at, app_version, ios_version, device_model, notes
             FROM users WHERE api_token = :token LIMIT 1'
        );

        try {
            $stmt->execute(['token' => $hash]);
            $user = $stmt->fetch();
        } catch (\PDOException) {
            // Older schema without admin columns.
            $stmt = $db->prepare(
                'SELECT id, display_name, email, api_token, created_at FROM users WHERE api_token = :token LIMIT 1'
            );
            $stmt->execute(['token' => $hash]);
            $user = $stmt->fetch();
        }

        if (!$user) {
            $stmt->execute(['token' => $token]);
            $user = $stmt->fetch();
            if ($user) {
                $upgrade = $db->prepare('UPDATE users SET api_token = :hash WHERE id = :id');
                $upgrade->execute([
                    'hash' => $hash,
                    'id' => (int) $user['id'],
                ]);
                $user['api_token'] = $hash;
            }
        }

        return $user ?: null;
    }

    public static function requireUser(PDO $db): array
    {
        $user = self::authenticate($db);
        if ($user === null) {
            Response::error('Unauthorized', 401);
        }
        if ((int) ($user['is_banned'] ?? 0) === 1) {
            Response::error('This account has been suspended.', 403, 'account_banned');
        }

        return $user;
    }

    public static function requireAdmin(PDO $db): array
    {
        $user = self::requireUser($db);
        if ((int) ($user['is_admin'] ?? 0) !== 1) {
            Response::error('Admin access required', 403);
        }

        return $user;
    }
}
