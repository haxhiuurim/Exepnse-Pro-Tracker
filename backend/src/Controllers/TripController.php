<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\Auth;
use Inpenso\RateLimiter;
use Inpenso\Response;
use PDO;
use PDOException;

final class TripController
{
    public function __construct(private PDO $db)
    {
    }

    public function create(): void
    {
        $user = Auth::requireUser($this->db);
        $body = Response::readJsonBody();

        $name = trim((string) ($body['name'] ?? ''));
        $currency = strtoupper(trim((string) ($body['currency'] ?? 'USD')));
        $startDate = $this->nullableDate($body['start_date'] ?? null);
        $endDate = $this->nullableDate($body['end_date'] ?? null);

        if ($name === '') {
            Response::error('name is required', 422);
        }

        if (mb_strlen($name) > 200) {
            Response::error('name must be 200 characters or fewer', 422);
        }

        if (!preg_match('/^[A-Z]{3}$/', $currency)) {
            Response::error('currency must be a 3-letter ISO code', 422);
        }

        if ($startDate !== null && $endDate !== null && $startDate > $endDate) {
            Response::error('start_date cannot be after end_date', 422);
        }

        $inviteCode = $this->generateUniqueInviteCode();

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare(
                'INSERT INTO trips (name, currency, start_date, end_date, invite_code, owner_id, created_at)
                 VALUES (:name, :currency, :start_date, :end_date, :invite_code, :owner_id, :created_at)'
            );
            $stmt->execute([
                'name' => $name,
                'currency' => $currency,
                'start_date' => $startDate,
                'end_date' => $endDate,
                'invite_code' => $inviteCode,
                'owner_id' => (int) $user['id'],
                'created_at' => gmdate('Y-m-d H:i:s'),
            ]);

            $tripId = (int) $this->db->lastInsertId();

            $memberStmt = $this->db->prepare(
                'INSERT INTO trip_members (trip_id, user_id, joined_at) VALUES (:trip_id, :user_id, :joined_at)'
            );
            $memberStmt->execute([
                'trip_id' => $tripId,
                'user_id' => (int) $user['id'],
                'joined_at' => gmdate('Y-m-d H:i:s'),
            ]);

            $this->db->commit();
        } catch (PDOException $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            $hint = $e->getMessage();
            if (str_contains(strtolower($hint), 'no such table')
                || str_contains(strtolower($hint), "doesn't exist")) {
                Response::error('Database not migrated. Run: php scripts/migrate.php', 500);
            }
            Response::error('Failed to create trip: ' . $hint, 500);
        }

        $trip = $this->fetchTripById($tripId);
        Response::success($trip, 201);
    }

    public function join(): void
    {
        $user = Auth::requireUser($this->db);
        RateLimiter::enforce('trips.join', 20, 3600);

        $body = Response::readJsonBody();
        $inviteCode = strtoupper(trim((string) ($body['invite_code'] ?? '')));

        if ($inviteCode === '') {
            Response::error('invite_code is required', 422);
        }

        if (!preg_match('/^[A-Z0-9]{6,16}$/', $inviteCode)) {
            Response::error('Invalid invite code', 422);
        }

        $stmt = $this->db->prepare('SELECT * FROM trips WHERE invite_code = :invite_code LIMIT 1');
        $stmt->execute(['invite_code' => $inviteCode]);
        $trip = $stmt->fetch();

        if (!$trip) {
            Response::error('Trip not found', 404);
        }

        $tripId = (int) $trip['id'];

        $existing = $this->db->prepare(
            'SELECT id FROM trip_members WHERE trip_id = :trip_id AND user_id = :user_id LIMIT 1'
        );
        $existing->execute(['trip_id' => $tripId, 'user_id' => (int) $user['id']]);

        if (!$existing->fetch()) {
            $insert = $this->db->prepare(
                'INSERT INTO trip_members (trip_id, user_id, joined_at) VALUES (:trip_id, :user_id, :joined_at)'
            );
            $insert->execute([
                'trip_id' => $tripId,
                'user_id' => (int) $user['id'],
                'joined_at' => gmdate('Y-m-d H:i:s'),
            ]);
        }

        Response::success($this->getTripDetail($tripId, (int) $user['id']));
    }

    public function list(): void
    {
        $user = Auth::requireUser($this->db);

        $stmt = $this->db->prepare(
            'SELECT t.*,
                    (SELECT COUNT(*) FROM trip_members tm WHERE tm.trip_id = t.id) AS member_count,
                    (SELECT COUNT(*) FROM expenses e WHERE e.trip_id = t.id) AS expense_count,
                    (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e WHERE e.trip_id = t.id) AS total_spent
             FROM trips t
             INNER JOIN trip_members m ON m.trip_id = t.id
             WHERE m.user_id = :user_id
             ORDER BY t.created_at DESC'
        );
        $stmt->execute(['user_id' => (int) $user['id']]);
        $trips = $stmt->fetchAll();

        Response::success(array_map(fn (array $trip) => $this->formatTripSummary($trip, (int) $user['id']), $trips));
    }

    public function show(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;

        if (!$this->userIsMember($id, (int) $user['id'])) {
            Response::error('Trip not found', 404);
        }

        Response::success($this->getTripDetail($id, (int) $user['id']));
    }

    public function leave(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;

        $trip = $this->fetchTripById($id);
        if ($trip === null) {
            Response::error('Trip not found', 404);
        }

        if ((int) $trip['owner_id'] === (int) $user['id']) {
            Response::error('Trip owner cannot leave. Delete the trip instead.', 422);
        }

        if (!$this->userIsMember($id, (int) $user['id'])) {
            Response::error('You are not a member of this trip', 404);
        }

        $member = $this->fetchMemberByUser($id, (int) $user['id']);
        if ($member === null) {
            Response::error('You are not a member of this trip', 404);
        }

        $expenseCount = $this->countMemberExpenses((int) $member['id']);
        if ($expenseCount > 0) {
            Response::error('Cannot leave trip while you are referenced in expenses', 422);
        }

        $stmt = $this->db->prepare('DELETE FROM trip_members WHERE id = :id');
        $stmt->execute(['id' => (int) $member['id']]);

        Response::success(['left' => true, 'trip_id' => $id]);
    }

    public function delete(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;

        $trip = $this->fetchTripById($id);
        if ($trip === null) {
            Response::error('Trip not found', 404);
        }

        if ((int) $trip['owner_id'] !== (int) $user['id']) {
            Response::error('Only the trip owner can delete this trip', 403);
        }

        $stmt = $this->db->prepare('DELETE FROM trips WHERE id = :id');
        $stmt->execute(['id' => $id]);

        Response::success(['deleted' => true, 'trip_id' => $id]);
    }

    private function getTripDetail(int $tripId, int $userId): array
    {
        $trip = $this->fetchTripById($tripId);
        if ($trip === null) {
            Response::error('Trip not found', 404);
        }

        $members = $this->fetchMembers($tripId);
        $expenses = $this->fetchExpenses($tripId);
        $balances = $this->calculateBalances($members, $expenses);

        $formatted = $this->formatTrip($trip);
        $formatted['is_owner'] = (int) $trip['owner_id'] === $userId;
        $formatted['members'] = $members;
        $formatted['expenses'] = $expenses;
        $formatted['balances'] = $balances;

        return $formatted;
    }

    private function fetchTripById(int $tripId): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM trips WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $tripId]);
        $trip = $stmt->fetch();

        return $trip ?: null;
    }

    private function fetchMembers(int $tripId): array
    {
        $stmt = $this->db->prepare(
            'SELECT m.id, m.trip_id, m.user_id, m.joined_at, u.display_name
             FROM trip_members m
             INNER JOIN users u ON u.id = m.user_id
             WHERE m.trip_id = :trip_id
             ORDER BY m.joined_at ASC'
        );
        $stmt->execute(['trip_id' => $tripId]);
        $rows = $stmt->fetchAll();

        return array_map(function (array $row): array {
            return [
                'id' => (int) $row['id'],
                'trip_id' => (int) $row['trip_id'],
                'user_id' => (int) $row['user_id'],
                'display_name' => $row['display_name'],
                'joined_at' => $row['joined_at'],
            ];
        }, $rows);
    }

    private function fetchExpenses(int $tripId): array
    {
        $stmt = $this->db->prepare(
            'SELECT e.id, e.trip_id, e.title, e.amount, e.paid_by_member_id, e.created_by_user_id, e.created_at,
                    payer.display_name AS paid_by_display_name
             FROM expenses e
             INNER JOIN trip_members pm ON pm.id = e.paid_by_member_id
             INNER JOIN users payer ON payer.id = pm.user_id
             WHERE e.trip_id = :trip_id
             ORDER BY e.created_at DESC, e.id DESC'
        );
        $stmt->execute(['trip_id' => $tripId]);
        $expenses = $stmt->fetchAll();

        $result = [];
        foreach ($expenses as $expense) {
            $splitStmt = $this->db->prepare(
                'SELECT s.member_id, s.amount, u.display_name
                 FROM expense_splits s
                 INNER JOIN trip_members m ON m.id = s.member_id
                 INNER JOIN users u ON u.id = m.user_id
                 WHERE s.expense_id = :expense_id
                 ORDER BY s.member_id ASC'
            );
            $splitStmt->execute(['expense_id' => (int) $expense['id']]);
            $splits = $splitStmt->fetchAll();

            $result[] = [
                'id' => (int) $expense['id'],
                'trip_id' => (int) $expense['trip_id'],
                'title' => $expense['title'],
                'amount' => $this->formatMoney($expense['amount']),
                'paid_by_member_id' => (int) $expense['paid_by_member_id'],
                'paid_by_display_name' => $expense['paid_by_display_name'],
                'created_by_user_id' => (int) $expense['created_by_user_id'],
                'created_at' => $expense['created_at'],
                'splits' => array_map(fn (array $split) => [
                    'member_id' => (int) $split['member_id'],
                    'display_name' => $split['display_name'],
                    'amount' => $this->formatMoney($split['amount']),
                ], $splits),
            ];
        }

        return $result;
    }

    /**
     * @param array<int, array<string, mixed>> $members
     * @param array<int, array<string, mixed>> $expenses
     */
    private function calculateBalances(array $members, array $expenses): array
    {
        $net = [];
        foreach ($members as $member) {
            $net[(int) $member['id']] = [
                'member_id' => (int) $member['id'],
                'display_name' => $member['display_name'],
                'paid' => 0.0,
                'owed' => 0.0,
                'net' => 0.0,
            ];
        }

        foreach ($expenses as $expense) {
            $paidBy = (int) $expense['paid_by_member_id'];
            $amount = (float) $expense['amount'];

            if (isset($net[$paidBy])) {
                $net[$paidBy]['paid'] += $amount;
            }

            foreach ($expense['splits'] as $split) {
                $memberId = (int) $split['member_id'];
                $splitAmount = (float) $split['amount'];
                if (isset($net[$memberId])) {
                    $net[$memberId]['owed'] += $splitAmount;
                }
            }
        }

        $balances = [];
        foreach ($net as &$entry) {
            $entry['paid'] = $this->formatMoney($entry['paid']);
            $entry['owed'] = $this->formatMoney($entry['owed']);
            $entry['net'] = $this->formatMoney((float) $entry['paid'] - (float) $entry['owed']);
            $balances[] = $entry;
        }
        unset($entry);

        usort($balances, fn ($a, $b) => (float) $b['net'] <=> (float) $a['net']);

        return $balances;
    }

    private function userIsMember(int $tripId, int $userId): bool
    {
        $stmt = $this->db->prepare(
            'SELECT 1 FROM trip_members WHERE trip_id = :trip_id AND user_id = :user_id LIMIT 1'
        );
        $stmt->execute(['trip_id' => $tripId, 'user_id' => $userId]);

        return (bool) $stmt->fetchColumn();
    }

    private function fetchMemberByUser(int $tripId, int $userId): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM trip_members WHERE trip_id = :trip_id AND user_id = :user_id LIMIT 1'
        );
        $stmt->execute(['trip_id' => $tripId, 'user_id' => $userId]);
        $member = $stmt->fetch();

        return $member ?: null;
    }

    private function countMemberExpenses(int $memberId): int
    {
        $paid = $this->db->prepare('SELECT COUNT(*) FROM expenses WHERE paid_by_member_id = :member_id');
        $paid->execute(['member_id' => $memberId]);

        $split = $this->db->prepare('SELECT COUNT(*) FROM expense_splits WHERE member_id = :member_id');
        $split->execute(['member_id' => $memberId]);

        return (int) $paid->fetchColumn() + (int) $split->fetchColumn();
    }

    private function generateUniqueInviteCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $length = 12;

        for ($attempt = 0; $attempt < 20; $attempt++) {
            $code = '';
            for ($i = 0; $i < $length; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }

            $stmt = $this->db->prepare('SELECT 1 FROM trips WHERE invite_code = :code LIMIT 1');
            $stmt->execute(['code' => $code]);
            if (!$stmt->fetchColumn()) {
                return $code;
            }
        }

        Response::error('Could not generate invite code', 500);
    }

    private function formatTrip(array $trip): array
    {
        return [
            'id' => (int) $trip['id'],
            'name' => $trip['name'],
            'currency' => $trip['currency'],
            'start_date' => $trip['start_date'],
            'end_date' => $trip['end_date'],
            'invite_code' => $trip['invite_code'],
            'owner_id' => (int) $trip['owner_id'],
            'created_at' => $trip['created_at'],
        ];
    }

    private function formatTripSummary(array $trip, int $userId): array
    {
        $formatted = $this->formatTrip($trip);
        $formatted['is_owner'] = (int) $trip['owner_id'] === $userId;
        $formatted['member_count'] = (int) ($trip['member_count'] ?? 0);
        $formatted['expense_count'] = (int) ($trip['expense_count'] ?? 0);
        $formatted['total_spent'] = $this->formatMoney($trip['total_spent'] ?? 0);

        return $formatted;
    }

    private function nullableDate(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        $date = trim((string) $value);
        $dt = \DateTimeImmutable::createFromFormat('Y-m-d', $date);
        if (!$dt || $dt->format('Y-m-d') !== $date) {
            Response::error('Dates must use YYYY-MM-DD format', 422);
        }

        return $date;
    }

    private function formatMoney(mixed $value): string
    {
        return number_format((float) $value, 2, '.', '');
    }
}
