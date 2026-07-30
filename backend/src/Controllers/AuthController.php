<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\Auth;
use Inpenso\RateLimiter;
use Inpenso\Response;
use PDO;

final class AuthController
{
    public function __construct(private PDO $db)
    {
    }

    public function register(): void
    {
        RateLimiter::enforce('auth.register', 10, 3600);

        $config = \Inpenso\AppConfig::publicPayload($this->db);
        if (empty($config['features']['registration'])) {
            Response::error('Registration is temporarily disabled.', 403);
        }

        $body = Response::readJsonBody();
        $email = strtolower(trim((string) ($body['email'] ?? '')));
        $password = (string) ($body['password'] ?? '');
        $displayName = trim((string) ($body['display_name'] ?? ''));

        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Response::error('A valid email is required', 422);
        }
        if (strlen($password) < 8) {
            Response::error('Password must be at least 8 characters', 422);
        }
        if ($displayName === '') {
            $displayName = explode('@', $email)[0];
        }
        if (mb_strlen($displayName) > 100) {
            Response::error('display_name must be 100 characters or fewer', 422);
        }

        $exists = $this->db->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
        $exists->execute(['email' => $email]);
        if ($exists->fetch()) {
            Response::error('An account with this email already exists', 409);
        }

        $token = Auth::generateToken();
        $tokenHash = Auth::hashToken($token);
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        $now = gmdate('Y-m-d H:i:s');

        try {
            $stmt = $this->db->prepare(
                'INSERT INTO users (email, password_hash, display_name, api_token, created_at, updated_at)
                 VALUES (:email, :password_hash, :display_name, :api_token, :created_at, :updated_at)'
            );
            $stmt->execute([
                'email' => $email,
                'password_hash' => $passwordHash,
                'display_name' => $displayName,
                'api_token' => $tokenHash,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } catch (\PDOException $e) {
            Response::error('Registration failed: ' . $e->getMessage(), 500);
        }

        $userId = (int) $this->db->lastInsertId();

        Response::success([
            'user_id' => $userId,
            'email' => $email,
            'display_name' => $displayName,
            'api_token' => $token,
        ], 201);
    }

    public function login(): void
    {
        RateLimiter::enforce('auth.login', 20, 3600);

        $body = Response::readJsonBody();
        $email = strtolower(trim((string) ($body['email'] ?? '')));
        $password = (string) ($body['password'] ?? '');

        if ($email === '' || $password === '') {
            Response::error('email and password are required', 422);
        }

        $stmt = $this->db->prepare(
            'SELECT id, email, display_name, password_hash FROM users WHERE email = :email LIMIT 1'
        );
        $stmt->execute(['email' => $email]);
        $user = $stmt->fetch();

        if (!$user || empty($user['password_hash']) || !password_verify($password, (string) $user['password_hash'])) {
            Response::error('Invalid email or password', 401);
        }

        $token = Auth::generateToken();
        $tokenHash = Auth::hashToken($token);
        $now = gmdate('Y-m-d H:i:s');

        $update = $this->db->prepare(
            'UPDATE users SET api_token = :token, updated_at = :updated_at WHERE id = :id'
        );
        $update->execute([
            'token' => $tokenHash,
            'updated_at' => $now,
            'id' => (int) $user['id'],
        ]);

        Response::success([
            'user_id' => (int) $user['id'],
            'email' => $user['email'],
            'display_name' => $user['display_name'],
            'api_token' => $token,
        ]);
    }

    public function me(): void
    {
        $user = Auth::requireUser($this->db);
        Response::success([
            'user_id' => (int) $user['id'],
            'email' => $user['email'] ?? null,
            'display_name' => $user['display_name'],
            'is_admin' => (int) ($user['is_admin'] ?? 0) === 1,
            'premium' => \Inpenso\UserActivity::isPremium($user),
            'premium_until' => $user['premium_until'] ?? null,
            'premium_note' => $user['premium_note'] ?? null,
        ]);
    }

    public function logout(): void
    {
        $user = Auth::requireUser($this->db);
        $token = Auth::generateToken();
        $stmt = $this->db->prepare(
            'UPDATE users SET api_token = :token, updated_at = :updated_at WHERE id = :id'
        );
        $stmt->execute([
            'token' => Auth::hashToken($token),
            'updated_at' => gmdate('Y-m-d H:i:s'),
            'id' => (int) $user['id'],
        ]);
        Response::success(['logged_out' => true]);
    }
}
