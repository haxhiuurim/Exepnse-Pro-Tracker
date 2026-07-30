<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\AppConfig;
use Inpenso\Auth;
use Inpenso\Response;
use Inpenso\UserActivity;
use PDO;

final class AdminController
{
    public function __construct(private PDO $db)
    {
    }

    public function dashboard(): void
    {
        Auth::requireAdmin($this->db);

        $users = (int) $this->db->query('SELECT COUNT(*) FROM users')->fetchColumn();
        $admins = (int) $this->db->query('SELECT COUNT(*) FROM users WHERE is_admin = 1')->fetchColumn();
        $banned = (int) $this->db->query('SELECT COUNT(*) FROM users WHERE is_banned = 1')->fetchColumn();
        $weekAgo = gmdate('Y-m-d H:i:s', time() - 7 * 86400);
        $monthAgo = gmdate('Y-m-d H:i:s', time() - 30 * 86400);
        $now = gmdate('Y-m-d H:i:s');

        $premiumStmt = $this->db->prepare(
            'SELECT COUNT(*) FROM users WHERE premium_until IS NOT NULL AND premium_until >= :now'
        );
        $premiumStmt->execute(['now' => $now]);
        $premium = (int) $premiumStmt->fetchColumn();

        $active7Stmt = $this->db->prepare(
            'SELECT COUNT(*) FROM users WHERE last_seen_at IS NOT NULL AND last_seen_at >= :t'
        );
        $active7Stmt->execute(['t' => $weekAgo]);
        $active7 = (int) $active7Stmt->fetchColumn();

        $active30Stmt = $this->db->prepare(
            'SELECT COUNT(*) FROM users WHERE last_seen_at IS NOT NULL AND last_seen_at >= :t'
        );
        $active30Stmt->execute(['t' => $monthAgo]);
        $active30 = (int) $active30Stmt->fetchColumn();

        $new7Stmt = $this->db->prepare('SELECT COUNT(*) FROM users WHERE created_at >= :t');
        $new7Stmt->execute(['t' => $weekAgo]);
        $new7 = (int) $new7Stmt->fetchColumn();

        $devices = (int) $this->db->query('SELECT COUNT(*) FROM devices')->fetchColumn();
        $guestDevices = (int) $this->db->query('SELECT COUNT(*) FROM devices WHERE is_guest = 1 OR user_id IS NULL')->fetchColumn();
        $trips = (int) $this->db->query('SELECT COUNT(*) FROM trips')->fetchColumn();
        $tripExpenses = (int) $this->db->query('SELECT COUNT(*) FROM expenses')->fetchColumn();

        $config = AppConfig::publicPayload($this->db);

        Response::success([
            'stats' => [
                'users' => $users,
                'admins' => $admins,
                'banned' => $banned,
                'premium_grants' => $premium,
                'devices' => $devices,
                'guest_devices' => $guestDevices,
                'trips' => $trips,
                'trip_expenses' => $tripExpenses,
                'active_users_7d' => $active7,
                'active_users_30d' => $active30,
                'new_users_7d' => $new7,
            ],
            'config_snapshot' => $config,
            'server_time' => gmdate('c'),
        ]);
    }

    public function listUsers(): void
    {
        Auth::requireAdmin($this->db);

        $q = trim((string) ($_GET['q'] ?? ''));
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $perPage = min(100, max(10, (int) ($_GET['per_page'] ?? 25)));
        $offset = ($page - 1) * $perPage;
        $filter = (string) ($_GET['filter'] ?? 'all'); // all|premium|banned|admin|inactive

        $where = ['1=1'];
        $params = [];
        if ($q !== '') {
            $where[] = '(email LIKE :q OR display_name LIKE :q OR CAST(id AS CHAR) LIKE :q)';
            $params['q'] = '%' . $q . '%';
        }
        if ($filter === 'premium') {
            $where[] = 'premium_until IS NOT NULL AND premium_until >= :now';
            $params['now'] = gmdate('Y-m-d H:i:s');
        } elseif ($filter === 'banned') {
            $where[] = 'is_banned = 1';
        } elseif ($filter === 'admin') {
            $where[] = 'is_admin = 1';
        } elseif ($filter === 'inactive') {
            $where[] = '(last_seen_at IS NULL OR last_seen_at < :inactive)';
            $params['inactive'] = gmdate('Y-m-d H:i:s', time() - 30 * 86400);
        }

        $whereSql = implode(' AND ', $where);
        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM users WHERE {$whereSql}");
        $countStmt->execute($params);
        $total = (int) $countStmt->fetchColumn();

        $sql = "SELECT id, email, display_name, is_admin, is_banned, premium_until, premium_note,
                       last_seen_at, last_data_at, app_version, ios_version, device_model,
                       created_at, updated_at, notes
                FROM users
                WHERE {$whereSql}
                ORDER BY COALESCE(last_seen_at, created_at) DESC
                LIMIT {$perPage} OFFSET {$offset}";
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        Response::success([
            'total' => $total,
            'page' => $page,
            'per_page' => $perPage,
            'users' => array_map(fn (array $u) => $this->formatUser($u), $rows),
        ]);
    }

    public function showUser(string $id): void
    {
        Auth::requireAdmin($this->db);
        $userId = (int) $id;

        $stmt = $this->db->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $userId]);
        $user = $stmt->fetch();
        if (!$user) {
            Response::error('User not found', 404);
        }

        $devices = $this->db->prepare('SELECT * FROM devices WHERE user_id = :id ORDER BY last_seen_at DESC');
        $devices->execute(['id' => $userId]);

        $trips = $this->db->prepare(
            'SELECT t.id, t.name, t.invite_code, t.currency, t.created_at,
                    (SELECT COUNT(*) FROM trip_members m WHERE m.trip_id = t.id) AS member_count
             FROM trips t
             INNER JOIN trip_members m ON m.trip_id = t.id AND m.user_id = :id
             ORDER BY t.created_at DESC'
        );
        $trips->execute(['id' => $userId]);

        $docs = $this->db->prepare(
            'SELECT doc_type, LENGTH(payload) AS bytes, updated_at FROM sync_documents WHERE user_id = :id'
        );
        $docs->execute(['id' => $userId]);

        Response::success([
            'user' => $this->formatUser($user),
            'devices' => $devices->fetchAll(),
            'trips' => $trips->fetchAll(),
            'sync_documents' => $docs->fetchAll(),
        ]);
    }

    public function updateUser(string $id): void
    {
        $admin = Auth::requireAdmin($this->db);
        $userId = (int) $id;
        $body = Response::readJsonBody();

        $stmt = $this->db->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $userId]);
        $user = $stmt->fetch();
        if (!$user) {
            Response::error('User not found', 404);
        }

        $sets = ['updated_at = :updated'];
        $params = ['updated' => gmdate('Y-m-d H:i:s'), 'id' => $userId];

        if (array_key_exists('is_banned', $body)) {
            $sets[] = 'is_banned = :is_banned';
            $params['is_banned'] = !empty($body['is_banned']) ? 1 : 0;
        }
        if (array_key_exists('is_admin', $body)) {
            if ($userId === (int) $admin['id'] && empty($body['is_admin'])) {
                Response::error('You cannot remove your own admin access', 422);
            }
            $sets[] = 'is_admin = :is_admin';
            $params['is_admin'] = !empty($body['is_admin']) ? 1 : 0;
        }
        if (array_key_exists('notes', $body)) {
            $sets[] = 'notes = :notes';
            $params['notes'] = $body['notes'] === null ? null : substr((string) $body['notes'], 0, 2000);
        }
        if (array_key_exists('display_name', $body)) {
            $name = trim((string) $body['display_name']);
            if ($name !== '') {
                $sets[] = 'display_name = :display_name';
                $params['display_name'] = mb_substr($name, 0, 100);
            }
        }
        if (array_key_exists('premium_until', $body)) {
            $until = $body['premium_until'];
            $sets[] = 'premium_until = :premium_until';
            if ($until === null || $until === '' || $until === false) {
                $params['premium_until'] = null;
            } elseif ($until === 'lifetime' || $until === true) {
                $params['premium_until'] = '9999-12-31 23:59:59';
            } else {
                $params['premium_until'] = (string) $until;
            }
        }
        if (array_key_exists('premium_note', $body)) {
            $sets[] = 'premium_note = :premium_note';
            $params['premium_note'] = $body['premium_note'] === null
                ? null
                : substr((string) $body['premium_note'], 0, 500);
        }
        if (array_key_exists('password', $body) || array_key_exists('new_password', $body)) {
            $password = (string) ($body['password'] ?? $body['new_password'] ?? '');
            if (strlen($password) < 8) {
                Response::error('password must be at least 8 characters', 422);
            }
            if (strlen($password) > 200) {
                Response::error('password is too long', 422);
            }
            $sets[] = 'password_hash = :password_hash';
            $params['password_hash'] = password_hash($password, PASSWORD_DEFAULT);
            // Force re-login on other sessions/devices for this account
            $sets[] = 'api_token = :api_token';
            $params['api_token'] = Auth::hashToken(Auth::generateToken());
        }

        if (count($sets) === 1) {
            Response::error('No changes provided', 422);
        }

        $this->db->prepare('UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = :id')->execute($params);

        $auditBody = $body;
        unset($auditBody['password'], $auditBody['new_password']);
        if (isset($body['password']) || isset($body['new_password'])) {
            $auditBody['password_changed'] = true;
        }
        UserActivity::audit($this->db, (int) $admin['id'], 'user.update', 'user', (string) $userId, $auditBody);

        $stmt->execute(['id' => $userId]);
        Response::success(['user' => $this->formatUser($stmt->fetch())]);
    }

    public function grantPremium(string $id): void
    {
        $admin = Auth::requireAdmin($this->db);
        $body = Response::readJsonBody();
        $days = (int) ($body['days'] ?? 0);
        $lifetime = !empty($body['lifetime']);
        $note = isset($body['note']) ? substr((string) $body['note'], 0, 500) : 'Granted by admin';

        if ($lifetime) {
            $until = '9999-12-31 23:59:59';
        } elseif ($days > 0) {
            $until = gmdate('Y-m-d H:i:s', time() + ($days * 86400));
        } else {
            Response::error('Provide days or lifetime=true', 422);
        }

        $this->updateUserFields((int) $id, [
            'premium_until' => $until,
            'premium_note' => $note,
        ]);
        UserActivity::audit($this->db, (int) $admin['id'], 'user.grant_premium', 'user', $id, [
            'until' => $until,
            'note' => $note,
        ]);

        $stmt = $this->db->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute(['id' => (int) $id]);
        Response::success(['user' => $this->formatUser($stmt->fetch())]);
    }

    public function revokePremium(string $id): void
    {
        $admin = Auth::requireAdmin($this->db);
        $this->updateUserFields((int) $id, [
            'premium_until' => null,
            'premium_note' => 'Revoked by admin',
        ]);
        UserActivity::audit($this->db, (int) $admin['id'], 'user.revoke_premium', 'user', $id, null);
        $stmt = $this->db->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute(['id' => (int) $id]);
        Response::success(['user' => $this->formatUser($stmt->fetch())]);
    }

    public function listDevices(): void
    {
        Auth::requireAdmin($this->db);
        $q = trim((string) ($_GET['q'] ?? ''));
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $perPage = min(100, max(10, (int) ($_GET['per_page'] ?? 25)));
        $offset = ($page - 1) * $perPage;
        $guestOnly = ($_GET['guests'] ?? '') === '1';

        $where = ['1=1'];
        $params = [];
        if ($guestOnly) {
            $where[] = '(d.is_guest = 1 OR d.user_id IS NULL)';
        }
        if ($q !== '') {
            $where[] = '(d.device_uuid LIKE :q OR d.device_model LIKE :q OR u.email LIKE :q OR u.display_name LIKE :q)';
            $params['q'] = '%' . $q . '%';
        }
        $whereSql = implode(' AND ', $where);

        $count = $this->db->prepare(
            "SELECT COUNT(*) FROM devices d LEFT JOIN users u ON u.id = d.user_id WHERE {$whereSql}"
        );
        $count->execute($params);
        $total = (int) $count->fetchColumn();

        $stmt = $this->db->prepare(
            "SELECT d.*, u.email AS user_email, u.display_name AS user_display_name
             FROM devices d
             LEFT JOIN users u ON u.id = d.user_id
             WHERE {$whereSql}
             ORDER BY d.last_seen_at DESC
             LIMIT {$perPage} OFFSET {$offset}"
        );
        $stmt->execute($params);

        Response::success([
            'total' => $total,
            'page' => $page,
            'per_page' => $perPage,
            'devices' => $stmt->fetchAll(),
        ]);
    }

    public function getConfig(): void
    {
        Auth::requireAdmin($this->db);
        Response::success([
            'config' => AppConfig::all($this->db),
            'defaults' => AppConfig::DEFAULTS,
            'public' => AppConfig::publicPayload($this->db),
        ]);
    }

    public function updateConfig(): void
    {
        $admin = Auth::requireAdmin($this->db);
        $body = Response::readJsonBody();
        $values = $body['config'] ?? $body;
        if (!is_array($values)) {
            Response::error('config object required', 422);
        }

        foreach ($values as $key => $value) {
            $key = (string) $key;
            if (!array_key_exists($key, AppConfig::DEFAULTS)) {
                continue;
            }
            if (is_bool($value)) {
                $value = $value ? '1' : '0';
            }
            AppConfig::set($this->db, $key, (string) $value, (int) $admin['id']);
        }

        UserActivity::audit($this->db, (int) $admin['id'], 'config.update', 'config', null, $values);
        Response::success([
            'config' => AppConfig::all($this->db),
            'public' => AppConfig::publicPayload($this->db),
        ]);
    }

    public function listTrips(): void
    {
        Auth::requireAdmin($this->db);
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $perPage = min(100, max(10, (int) ($_GET['per_page'] ?? 25)));
        $offset = ($page - 1) * $perPage;

        $total = (int) $this->db->query('SELECT COUNT(*) FROM trips')->fetchColumn();
        $stmt = $this->db->query(
            "SELECT t.id, t.name, t.invite_code, t.currency, t.created_at, t.owner_id,
                    u.email AS owner_email, u.display_name AS owner_name,
                    (SELECT COUNT(*) FROM trip_members m WHERE m.trip_id = t.id) AS member_count,
                    (SELECT COUNT(*) FROM expenses e WHERE e.trip_id = t.id) AS expense_count
             FROM trips t
             LEFT JOIN users u ON u.id = t.owner_id
             ORDER BY t.created_at DESC
             LIMIT {$perPage} OFFSET {$offset}"
        );

        Response::success([
            'total' => $total,
            'page' => $page,
            'trips' => $stmt->fetchAll(),
        ]);
    }

    public function listAudit(): void
    {
        Auth::requireAdmin($this->db);
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $perPage = min(100, max(10, (int) ($_GET['per_page'] ?? 50)));
        $offset = ($page - 1) * $perPage;

        $total = (int) $this->db->query('SELECT COUNT(*) FROM admin_audit_log')->fetchColumn();
        $stmt = $this->db->query(
            "SELECT a.*, u.email AS admin_email, u.display_name AS admin_name
             FROM admin_audit_log a
             LEFT JOIN users u ON u.id = a.admin_user_id
             ORDER BY a.created_at DESC
             LIMIT {$perPage} OFFSET {$offset}"
        );

        Response::success([
            'total' => $total,
            'page' => $page,
            'events' => $stmt->fetchAll(),
        ]);
    }

    public function deleteUser(string $id): void
    {
        $admin = Auth::requireAdmin($this->db);
        $userId = (int) $id;
        if ($userId === (int) $admin['id']) {
            Response::error('You cannot delete your own account', 422);
        }
        $stmt = $this->db->prepare('SELECT id, email FROM users WHERE id = :id');
        $stmt->execute(['id' => $userId]);
        $user = $stmt->fetch();
        if (!$user) {
            Response::error('User not found', 404);
        }
        $this->db->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $userId]);
        UserActivity::audit($this->db, (int) $admin['id'], 'user.delete', 'user', (string) $userId, [
            'email' => $user['email'],
        ]);
        Response::success(['deleted' => true]);
    }

    private function updateUserFields(int $userId, array $fields): void
    {
        $sets = ['updated_at = :updated'];
        $params = ['updated' => gmdate('Y-m-d H:i:s'), 'id' => $userId];
        foreach ($fields as $k => $v) {
            $sets[] = "{$k} = :{$k}";
            $params[$k] = $v;
        }
        $this->db->prepare('UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = :id')->execute($params);
    }

    private function formatUser(?array $user): ?array
    {
        if (!$user) {
            return null;
        }
        return [
            'id' => (int) $user['id'],
            'email' => $user['email'] ?? null,
            'display_name' => $user['display_name'] ?? null,
            'is_admin' => (int) ($user['is_admin'] ?? 0) === 1,
            'is_banned' => (int) ($user['is_banned'] ?? 0) === 1,
            'premium' => UserActivity::isPremium($user),
            'premium_until' => $user['premium_until'] ?? null,
            'premium_note' => $user['premium_note'] ?? null,
            'last_seen_at' => $user['last_seen_at'] ?? null,
            'last_data_at' => $user['last_data_at'] ?? null,
            'app_version' => $user['app_version'] ?? null,
            'ios_version' => $user['ios_version'] ?? null,
            'device_model' => $user['device_model'] ?? null,
            'notes' => $user['notes'] ?? null,
            'created_at' => $user['created_at'] ?? null,
            'updated_at' => $user['updated_at'] ?? null,
        ];
    }
}
