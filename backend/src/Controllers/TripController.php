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
                'INSERT INTO trips (name, currency, start_date, end_date, invite_code, owner_id, require_join_approval, created_at)
                 VALUES (:name, :currency, :start_date, :end_date, :invite_code, :owner_id, 1, :created_at)'
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
                'INSERT INTO trip_members (trip_id, user_id, display_name, is_manual, joined_at)
                 VALUES (:trip_id, :user_id, :display_name, 0, :joined_at)'
            );
            $memberStmt->execute([
                'trip_id' => $tripId,
                'user_id' => (int) $user['id'],
                'display_name' => $user['display_name'] ?? 'Owner',
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
        $userId = (int) $user['id'];

        if ($this->userIsMember($tripId, $userId)) {
            Response::success([
                'status' => 'already_member',
                'trip' => $this->getTripDetail($tripId, $userId),
            ]);
        }

        $requiresApproval = (int) ($trip['require_join_approval'] ?? 1) === 1;

        if (!$requiresApproval) {
            $insert = $this->db->prepare(
                'INSERT INTO trip_members (trip_id, user_id, display_name, is_manual, joined_at)
                 VALUES (:trip_id, :user_id, :display_name, 0, :joined_at)'
            );
            $insert->execute([
                'trip_id' => $tripId,
                'user_id' => $userId,
                'display_name' => $user['display_name'] ?? 'Member',
                'joined_at' => gmdate('Y-m-d H:i:s'),
            ]);
            Response::success([
                'status' => 'joined',
                'trip' => $this->getTripDetail($tripId, $userId),
            ]);
        }

        // Upsert pending join request
        $existing = $this->db->prepare(
            'SELECT id, status FROM trip_join_requests WHERE trip_id = :trip_id AND user_id = :user_id LIMIT 1'
        );
        $existing->execute(['trip_id' => $tripId, 'user_id' => $userId]);
        $request = $existing->fetch();

        if ($request && $request['status'] === 'pending') {
            Response::success([
                'status' => 'pending',
                'message' => 'Join request already pending owner approval',
                'trip' => $this->formatTrip($trip),
            ]);
        }

        if ($request && $request['status'] === 'declined') {
            $upd = $this->db->prepare(
                'UPDATE trip_join_requests SET status = :status, created_at = :created_at, resolved_at = NULL
                 WHERE id = :id'
            );
            $upd->execute([
                'status' => 'pending',
                'created_at' => gmdate('Y-m-d H:i:s'),
                'id' => (int) $request['id'],
            ]);
        } elseif (!$request) {
            $ins = $this->db->prepare(
                'INSERT INTO trip_join_requests (trip_id, user_id, status, created_at)
                 VALUES (:trip_id, :user_id, :status, :created_at)'
            );
            $ins->execute([
                'trip_id' => $tripId,
                'user_id' => $userId,
                'status' => 'pending',
                'created_at' => gmdate('Y-m-d H:i:s'),
            ]);
        }

        Response::success([
            'status' => 'pending',
            'message' => 'Join request sent. Waiting for the trip owner to approve.',
            'trip' => $this->formatTrip($trip),
        ], 202);
    }

    public function listJoinRequests(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;
        $trip = $this->fetchTripById($id);
        if ($trip === null || (int) $trip['owner_id'] !== (int) $user['id']) {
            Response::error('Only the trip owner can view join requests', 403);
        }

        $stmt = $this->db->prepare(
            'SELECT r.id, r.trip_id, r.user_id, r.status, r.created_at, u.display_name, u.email
             FROM trip_join_requests r
             INNER JOIN users u ON u.id = r.user_id
             WHERE r.trip_id = :trip_id AND r.status = :status
             ORDER BY r.created_at ASC'
        );
        $stmt->execute(['trip_id' => $id, 'status' => 'pending']);
        $rows = $stmt->fetchAll();

        Response::success(array_map(static fn (array $row): array => [
            'id' => (int) $row['id'],
            'trip_id' => (int) $row['trip_id'],
            'user_id' => (int) $row['user_id'],
            'display_name' => $row['display_name'],
            'email' => $row['email'],
            'status' => $row['status'],
            'created_at' => $row['created_at'],
        ], $rows));
    }

    public function acceptJoinRequest(string $tripId, string $requestId): void
    {
        $this->resolveJoinRequest($tripId, $requestId, true);
    }

    public function declineJoinRequest(string $tripId, string $requestId): void
    {
        $this->resolveJoinRequest($tripId, $requestId, false);
    }

    private function resolveJoinRequest(string $tripId, string $requestId, bool $accept): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;
        $reqId = (int) $requestId;

        $trip = $this->fetchTripById($id);
        if ($trip === null || (int) $trip['owner_id'] !== (int) $user['id']) {
            Response::error('Only the trip owner can manage join requests', 403);
        }

        $stmt = $this->db->prepare(
            'SELECT * FROM trip_join_requests WHERE id = :id AND trip_id = :trip_id LIMIT 1'
        );
        $stmt->execute(['id' => $reqId, 'trip_id' => $id]);
        $request = $stmt->fetch();
        if (!$request || $request['status'] !== 'pending') {
            Response::error('Join request not found', 404);
        }

        $now = gmdate('Y-m-d H:i:s');
        if ($accept) {
            if (!$this->userIsMember($id, (int) $request['user_id'])) {
                $nameStmt = $this->db->prepare('SELECT display_name FROM users WHERE id = :id LIMIT 1');
                $nameStmt->execute(['id' => (int) $request['user_id']]);
                $joinName = (string) ($nameStmt->fetchColumn() ?: 'Member');
                $insert = $this->db->prepare(
                    'INSERT INTO trip_members (trip_id, user_id, display_name, is_manual, joined_at)
                     VALUES (:trip_id, :user_id, :display_name, 0, :joined_at)'
                );
                $insert->execute([
                    'trip_id' => $id,
                    'user_id' => (int) $request['user_id'],
                    'display_name' => $joinName,
                    'joined_at' => $now,
                ]);
            }
            $status = 'accepted';
        } else {
            $status = 'declined';
        }

        $upd = $this->db->prepare(
            'UPDATE trip_join_requests SET status = :status, resolved_at = :resolved_at WHERE id = :id'
        );
        $upd->execute([
            'status' => $status,
            'resolved_at' => $now,
            'id' => $reqId,
        ]);

        Response::success([
            'status' => $status,
            'request_id' => $reqId,
            'trip' => $this->getTripDetail($id, (int) $user['id']),
        ]);
    }

    public function addManualMember(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;
        $trip = $this->fetchTripById($id);
        if ($trip === null || !$this->userIsMember($id, (int) $user['id'])) {
            Response::error('Trip not found', 404);
        }

        $body = Response::readJsonBody();
        $name = trim((string) ($body['display_name'] ?? $body['name'] ?? ''));
        if ($name === '') {
            Response::error('display_name is required', 422);
        }
        if (mb_strlen($name) > 100) {
            Response::error('display_name must be 100 characters or fewer', 422);
        }

        $ins = $this->db->prepare(
            'INSERT INTO trip_members (trip_id, user_id, display_name, is_manual, joined_at)
             VALUES (:trip_id, NULL, :display_name, 1, :joined_at)'
        );
        $ins->execute([
            'trip_id' => $id,
            'display_name' => $name,
            'joined_at' => gmdate('Y-m-d H:i:s'),
        ]);

        Response::success([
            'member_id' => (int) $this->db->lastInsertId(),
            'trip' => $this->getTripDetail($id, (int) $user['id']),
        ], 201);
    }

    public function removeMember(string $tripId, string $memberId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;
        $mid = (int) $memberId;
        $trip = $this->fetchTripById($id);
        if ($trip === null || (int) $trip['owner_id'] !== (int) $user['id']) {
            Response::error('Only the trip owner can remove members', 403);
        }

        $stmt = $this->db->prepare('SELECT * FROM trip_members WHERE id = :id AND trip_id = :trip_id LIMIT 1');
        $stmt->execute(['id' => $mid, 'trip_id' => $id]);
        $member = $stmt->fetch();
        if (!$member) {
            Response::error('Member not found', 404);
        }
        if ((int) ($member['user_id'] ?? 0) === (int) $trip['owner_id']) {
            Response::error('Cannot remove the trip owner', 422);
        }
        if ($this->countMemberExpenses($mid) > 0) {
            Response::error('Cannot remove a member who is on expenses. Settle or delete those first.', 422);
        }

        $this->db->prepare('DELETE FROM trip_members WHERE id = :id')->execute(['id' => $mid]);
        Response::success(['deleted' => true, 'trip' => $this->getTripDetail($id, (int) $user['id'])]);
    }

    public function settle(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;
        $trip = $this->fetchTripById($id);
        if ($trip === null || (int) $trip['owner_id'] !== (int) $user['id']) {
            Response::error('Only the trip owner can settle debts', 403);
        }

        $detail = $this->getTripDetail($id, (int) $user['id']);
        $now = gmdate('Y-m-d H:i:s');

        $this->db->beginTransaction();
        try {
            $snap = json_encode([
                'balances' => $detail['balances'] ?? [],
                'total_spent' => $detail['total_spent'] ?? '0.00',
            ], JSON_UNESCAPED_UNICODE);

            $ins = $this->db->prepare(
                'INSERT INTO trip_settlements (trip_id, settled_by_user_id, note, snapshot, created_at)
                 VALUES (:trip_id, :uid, :note, :snapshot, :created)'
            );
            $ins->execute([
                'trip_id' => $id,
                'uid' => (int) $user['id'],
                'note' => 'Owner settled outstanding balances',
                'snapshot' => $snap,
                'created' => $now,
            ]);

            $upd = $this->db->prepare(
                'UPDATE expenses SET is_settled = 1, settled_at = :t
                 WHERE trip_id = :trip_id AND COALESCE(is_settled, 0) = 0'
            );
            $upd->execute(['t' => $now, 'trip_id' => $id]);
            $this->db->commit();
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            Response::error('Settle failed: ' . $e->getMessage(), 500);
        }

        Response::success([
            'settled' => true,
            'trip' => $this->getTripDetail($id, (int) $user['id']),
        ]);
    }

    public function list(): void
    {
        $user = Auth::requireUser($this->db);
        $userId = (int) $user['id'];

        $stmt = $this->db->prepare(
            'SELECT t.*,
                    (SELECT COUNT(*) FROM trip_members tm WHERE tm.trip_id = t.id) AS member_count,
                    (SELECT COUNT(*) FROM expenses e WHERE e.trip_id = t.id) AS expense_count,
                    (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e WHERE e.trip_id = t.id) AS total_spent
             FROM trips t
             INNER JOIN trip_members m ON m.trip_id = t.id AND m.user_id = :user_id
             ORDER BY t.created_at DESC'
        );
        $stmt->execute(['user_id' => $userId]);
        $trips = $stmt->fetchAll();

        $summaries = [];
        foreach ($trips as $trip) {
            $summary = $this->formatTripSummary($trip, $userId);
            $detailBalances = $this->calculateBalances(
                $this->fetchMembers((int) $trip['id']),
                $this->fetchExpenses((int) $trip['id'], false)
            );
            $myMember = $this->fetchMemberByUser((int) $trip['id'], $userId);
            $myNet = 0.0;
            if ($myMember) {
                foreach ($detailBalances as $b) {
                    if ((int) $b['member_id'] === (int) $myMember['id']) {
                        $myNet = (float) $b['net'];
                        break;
                    }
                }
            }
            $summary['my_net'] = $this->formatMoney($myNet);
            $summaries[] = $summary;
        }

        Response::success($summaries);
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
        $expenses = $this->fetchExpenses($tripId, true);
        $balances = $this->calculateBalances($members, $this->fetchExpenses($tripId, false));

        $byMember = [];
        foreach ($balances as $b) {
            $byMember[(int) $b['member_id']] = $b;
        }

        $membersWithBalances = [];
        $myNet = 0.0;
        foreach ($members as $member) {
            $mid = (int) $member['id'];
            $bal = $byMember[$mid] ?? [
                'paid' => '0.00',
                'owed' => '0.00',
                'net' => '0.00',
            ];
            $member['paid'] = $bal['paid'];
            $member['owed'] = $bal['owed'];
            $member['net'] = $bal['net'];
            $membersWithBalances[] = $member;
            if ((int) ($member['user_id'] ?? 0) === $userId) {
                $myNet = (float) $bal['net'];
            }
        }

        $totalSpent = 0.0;
        $categoryTotals = [];
        foreach ($expenses as $expense) {
            $totalSpent += (float) $expense['amount'];
            $cat = trim((string) ($expense['category_name'] ?? ''));
            if ($cat === '') {
                $cat = 'Other';
            }
            if (!isset($categoryTotals[$cat])) {
                $categoryTotals[$cat] = 0.0;
            }
            $categoryTotals[$cat] += (float) $expense['amount'];
        }

        $categoryBreakdown = [];
        foreach ($categoryTotals as $name => $sum) {
            $categoryBreakdown[] = [
                'category_name' => $name,
                'amount' => $this->formatMoney($sum),
            ];
        }
        usort($categoryBreakdown, fn ($a, $b) => (float) $b['amount'] <=> (float) $a['amount']);

        $formatted = $this->formatTrip($trip);
        $formatted['is_owner'] = (int) $trip['owner_id'] === $userId;
        $formatted['members'] = $membersWithBalances;
        $formatted['expenses'] = $expenses;
        $formatted['balances'] = $balances;
        $formatted['total_spent'] = $this->formatMoney($totalSpent);
        $formatted['my_net'] = $this->formatMoney($myNet);
        $formatted['category_breakdown'] = $categoryBreakdown;
        $formatted['settlements'] = $this->fetchSettlements($tripId);

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
            'SELECT m.id, m.trip_id, m.user_id, m.joined_at,
                    m.display_name AS member_display_name,
                    COALESCE(m.is_manual, 0) AS is_manual,
                    u.display_name AS user_display_name
             FROM trip_members m
             LEFT JOIN users u ON u.id = m.user_id
             WHERE m.trip_id = :trip_id
             ORDER BY COALESCE(m.is_manual, 0) ASC, m.joined_at ASC, m.id ASC'
        );
        $stmt->execute(['trip_id' => $tripId]);
        $rows = $stmt->fetchAll();

        return array_map(function (array $row): array {
            $isManual = (int) ($row['is_manual'] ?? 0) === 1;
            $name = trim((string) ($row['member_display_name'] ?? ''));
            if ($name === '') {
                $name = trim((string) ($row['user_display_name'] ?? ''));
            }
            if ($name === '') {
                $name = $isManual ? 'Guest' : 'Member';
            }

            return [
                'id' => (int) $row['id'],
                'trip_id' => (int) $row['trip_id'],
                'user_id' => $row['user_id'] !== null ? (int) $row['user_id'] : null,
                'display_name' => $name,
                'is_manual' => $isManual,
                'joined_at' => $row['joined_at'],
            ];
        }, $rows);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchExpenses(int $tripId, bool $includeSettled = true): array
    {
        $sql = 'SELECT e.id, e.trip_id, e.title, e.amount, e.paid_by_member_id, e.created_by_user_id, e.created_at,
                       e.category_id, e.category_name, COALESCE(e.is_settled, 0) AS is_settled, e.settled_at,
                       COALESCE(NULLIF(pm.display_name, \'\'), up.display_name, \'Member\') AS paid_by_display_name,
                       COALESCE(uc.display_name, \'Member\') AS created_by_display_name
                FROM expenses e
                INNER JOIN trip_members pm ON pm.id = e.paid_by_member_id
                LEFT JOIN users up ON up.id = pm.user_id
                LEFT JOIN users uc ON uc.id = e.created_by_user_id
                WHERE e.trip_id = :trip_id';
        if (!$includeSettled) {
            $sql .= ' AND COALESCE(e.is_settled, 0) = 0';
        }
        $sql .= ' ORDER BY e.created_at DESC, e.id DESC';

        $stmt = $this->db->prepare($sql);
        $stmt->execute(['trip_id' => $tripId]);
        $expenses = $stmt->fetchAll();

        $result = [];
        foreach ($expenses as $expense) {
            $splitStmt = $this->db->prepare(
                'SELECT s.member_id, s.amount,
                        COALESCE(NULLIF(m.display_name, \'\'), u.display_name, \'Member\') AS display_name
                 FROM expense_splits s
                 INNER JOIN trip_members m ON m.id = s.member_id
                 LEFT JOIN users u ON u.id = m.user_id
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
                'created_by_display_name' => $expense['created_by_display_name'],
                'category_id' => $expense['category_id'] !== null ? (string) $expense['category_id'] : null,
                'category_name' => $expense['category_name'],
                'is_settled' => (int) ($expense['is_settled'] ?? 0) === 1,
                'settled_at' => $expense['settled_at'] ?? null,
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
     * @return array<int, array<string, mixed>>
     */
    private function fetchSettlements(int $tripId): array
    {
        try {
            $stmt = $this->db->prepare(
                'SELECT s.id, s.trip_id, s.settled_by_user_id, s.note, s.created_at, u.display_name
                 FROM trip_settlements s
                 LEFT JOIN users u ON u.id = s.settled_by_user_id
                 WHERE s.trip_id = :trip_id
                 ORDER BY s.created_at DESC'
            );
            $stmt->execute(['trip_id' => $tripId]);
            $rows = $stmt->fetchAll();
        } catch (PDOException) {
            return [];
        }

        return array_map(static fn (array $row): array => [
            'id' => (int) $row['id'],
            'trip_id' => (int) $row['trip_id'],
            'settled_by_user_id' => (int) $row['settled_by_user_id'],
            'settled_by_display_name' => $row['display_name'] ?? 'Owner',
            'note' => $row['note'],
            'created_at' => $row['created_at'],
        ], $rows);
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
            if (!empty($expense['is_settled'])) {
                continue;
            }
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
        foreach ($net as $entry) {
            $paid = (float) $entry['paid'];
            $owed = (float) $entry['owed'];
            $balances[] = [
                'member_id' => $entry['member_id'],
                'display_name' => $entry['display_name'],
                'paid' => $this->formatMoney($paid),
                'owed' => $this->formatMoney($owed),
                'net' => $this->formatMoney($paid - $owed),
            ];
        }

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
            'require_join_approval' => (int) ($trip['require_join_approval'] ?? 1) === 1,
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
