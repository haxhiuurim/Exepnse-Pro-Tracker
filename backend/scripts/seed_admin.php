<?php

declare(strict_types=1);

/**
 * Create or promote the default super-admin.
 *
 * Defaults (override with .env):
 *   ADMIN_EMAIL=admin@expense.app
 *   ADMIN_PASSWORD=adminadmin
 *   ADMIN_NAME=Admin
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

$email = strtolower(trim((string) ($_ENV['ADMIN_EMAIL'] ?? getenv('ADMIN_EMAIL') ?: 'admin@expense.app')));
$password = (string) ($_ENV['ADMIN_PASSWORD'] ?? getenv('ADMIN_PASSWORD') ?: 'adminadmin');
$name = trim((string) ($_ENV['ADMIN_NAME'] ?? getenv('ADMIN_NAME') ?: 'Admin'));

if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fwrite(STDERR, "ADMIN_EMAIL must be a valid email (default admin@expense.app).\n");
    exit(1);
}
if (strlen($password) < 8) {
    fwrite(STDERR, "ADMIN_PASSWORD must be at least 8 characters (default adminadmin).\n");
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
    echo "Updated super-admin #{$existing['id']} ({$email}).\n";
} else {
    // Prefer full column set; fall back if older schema.
    try {
        $ins = $db->prepare(
            'INSERT INTO users (email, password_hash, display_name, api_token, is_admin, is_banned, created_at, updated_at)
             VALUES (:email, :ph, :name, :token, 1, 0, :created, :updated)'
        );
        $ins->execute([
            'email' => $email,
            'ph' => $passHash,
            'name' => $name,
            'token' => $hash,
            'created' => $now,
            'updated' => $now,
        ]);
    } catch (Throwable $e) {
        fwrite(STDERR, "Insert failed — run php scripts/migrate.php first.\n" . $e->getMessage() . "\n");
        exit(1);
    }
    echo "Created super-admin {$email} (id " . $db->lastInsertId() . ").\n";
}

echo "\nSign in at /admin with:\n";
echo "  Email:    {$email}\n";
echo "  Password: {$password}\n";
echo "Change the password after first login (Users → open admin → or re-run seed with new ADMIN_PASSWORD).\n";
