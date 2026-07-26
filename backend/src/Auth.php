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

        $stmt = $db->prepare('SELECT id, display_name, api_token, created_at FROM users WHERE api_token = :token LIMIT 1');
        $stmt->execute(['token' => $token]);
        $user = $stmt->fetch();

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
