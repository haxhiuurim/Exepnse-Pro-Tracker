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

        // Reject obviously malformed tokens early (hex, 64 chars for new tokens).
        if (strlen($token) > 128) {
            return null;
        }

        $hash = self::hashToken($token);

        $stmt = $db->prepare(
            'SELECT id, display_name, api_token, created_at FROM users WHERE api_token = :token LIMIT 1'
        );
        $stmt->execute(['token' => $hash]);
        $user = $stmt->fetch();

        // Legacy plaintext tokens: upgrade to hash on successful auth.
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

        return $user;
    }
}
