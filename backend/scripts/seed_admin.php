<?php

declare(strict_types=1);

/**
 * Create or promote the super-admin account from .env:
 *   ADMIN_EMAIL=you@example.com
 *   ADMIN_PASSWORD=strong-password
 *   ADMIN_NAME=Super Admin
 *
 * Usage: php scripts/seed_admin.php
 */

$config = require dirname(__DIR__) . '/config.php';

spl_autoload_register(static function (string $class): void {
    $prefix = 'Inpenso\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }
    $relative = substr($class, strlen($prefix));
    $path = dirname(__DIR__) . '/src/' . str_replace('\\', '/', $relative) . '.php';
    if (is_readable($path)) {
        require $path;
    }
});

use Inpenso\Auth;
use Inpenso\Database;

$email = strtolower(trim((string) ($_ENV['ADMIN_EMAIL'] ?? getenv('ADMIN_EMAIL') ?: '')));
$password = (string) ($_ENV['ADMIN_PASSWORD'] ?? getenv('ADMIN_PASSWORD') ?: '');
$name = trim((string) ($_ENV['ADMIN_NAME'] ?? getenv('ADMIN_NAME') ?: 'Super Admin'));

if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fwrite(STDERR, "Set ADMIN_EMAIL in .env to a valid email.\n");
    exit(1);
}
if (strlen($password) < 10) {
    fwrite(STDERR, "Set ADMIN_PASSWORD in .env (min 10 characters).\n");
    exit(1);
}

$db = Database::connection($config);
$now = gmdate('Y-m-d H:i:s');
$token = Auth::generateToken();
$hash = Auth::hashToken($token);
$passHash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $db->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
$stmt->execute(['email' => $email]);
$existing = $stmt->fetch();

if ($existing) {
    $upd = $db->prepare(
        'UPDATE users SET password_hash = :ph, display_name = :name, is_admin = 1, is_banned = 0,
                api_token = :token, updated_at = :updated WHERE id = :id'
    );
    $upd->execute([
        'ph' => $passHash,
        'name' => $name,
        'token' => $hash,
        'updated' => $now,
        'id' => (int) $existing['id'],
    ]);
    echo "Promoted existing user #{$existing['id']} ({$email}) to super-admin.\n";
} else {
    $ins = $db->prepare(
        'INSERT INTO users (email, password_hash, display_name, api_token, is_admin, is_banned, created_at, updated_at)
         VALUES (:email, :ph, :name, :token, 1, 0, :created, :updated)'
    );
    try {
        $ins->execute([
            'email' => $email,
            'ph' => $passHash,
            'name' => $name,
            'token' => $hash,
            'created' => $now,
            'updated' => $now,
        ]);
    } catch (Throwable $e) {
        // Schema may still lack is_admin — run migrate first.
        fwrite(STDERR, "Insert failed (run php scripts/migrate.php first): " . $e->getMessage() . "\n");
        exit(1);
    }
    echo "Created super-admin {$email} (id " . $db->lastInsertId() . ").\n";
}

echo "Open https://your-host/admin and sign in with that email/password.\n";
