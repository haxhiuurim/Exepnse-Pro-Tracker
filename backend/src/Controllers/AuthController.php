<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\Auth;
use Inpenso\Response;
use PDO;
use RuntimeException;

final class AuthController
{
    public function __construct(private PDO $db)
    {
    }

    public function register(): void
    {
        $body = Response::readJsonBody();
        $displayName = trim((string) ($body['display_name'] ?? ''));

        if ($displayName === '') {
            Response::error('display_name is required', 422);
        }

        if (mb_strlen($displayName) > 100) {
            Response::error('display_name must be 100 characters or fewer', 422);
        }

        $token = Auth::generateToken();

        $stmt = $this->db->prepare(
            'INSERT INTO users (display_name, api_token, created_at) VALUES (:display_name, :api_token, :created_at)'
        );
        $stmt->execute([
            'display_name' => $displayName,
            'api_token' => $token,
            'created_at' => gmdate('Y-m-d H:i:s'),
        ]);

        $userId = (int) $this->db->lastInsertId();

        Response::success([
            'user_id' => $userId,
            'display_name' => $displayName,
            'api_token' => $token,
        ], 201);
    }
}
