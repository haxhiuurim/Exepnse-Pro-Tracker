<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\Auth;
use Inpenso\Response;
use PDO;
use PDOException;

final class ExpenseController
{
    public function __construct(private PDO $db)
    {
    }

    public function list(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;

        if (!$this->userIsMember($id, (int) $user['id'])) {
            Response::error('Trip not found', 404);
        }

        Response::success($this->fetchExpenses($id));
    }

    public function create(string $tripId): void
    {
        $user = Auth::requireUser($this->db);
        $id = (int) $tripId;

        if (!$this->userIsMember($id, (int) $user['id'])) {
            Response::error('Trip not found', 404);
        }

        $body = Response::readJsonBody();
        $title = trim((string) ($body['title'] ?? ''));
        $amount = $body['amount'] ?? null;
        $paidByMemberId = $body['paid_by_member_id'] ?? null;
        $splitMap = $body['split'] ?? null;
        $splitMemberIds = $body['split_member_ids'] ?? null;
        $categoryId = isset($body['category_id']) ? trim((string) $body['category_id']) : null;
        $categoryName = isset($body['category_name']) ? trim((string) $body['category_name']) : null;

        if ($title === '') {
            Response::error('title is required', 422);
        }

        if (mb_strlen($title) > 200) {
            Response::error('title must be 200 characters or fewer', 422);
        }

        if (!is_numeric($amount) || (float) $amount <= 0) {
            Response::error('amount must be a positive number', 422);
        }

        if ((float) $amount > 9999999999.99) {
            Response::error('amount is too large', 422);
        }

        $amountValue = round((float) $amount, 2);

        if (!is_numeric($paidByMemberId)) {
            Response::error('paid_by_member_id is required', 422);
        }

        $paidByMemberId = (int) $paidByMemberId;
        if (!$this->memberBelongsToTrip($id, $paidByMemberId)) {
            Response::error('paid_by_member_id is not a member of this trip', 422);
        }

        $allMembers = $this->fetchMemberIds($id);
        if ($allMembers === []) {
            Response::error('Trip has no members', 422);
        }

        $splitTargets = $allMembers;
        if (is_array($splitMemberIds) && $splitMemberIds !== []) {
            $splitTargets = [];
            foreach ($splitMemberIds as $rawId) {
                if (!is_numeric($rawId)) {
                    Response::error('split_member_ids must be member IDs', 422);
                }
                $mid = (int) $rawId;
                if (!in_array($mid, $allMembers, true)) {
                    Response::error("Member {$mid} is not part of this trip", 422);
                }
                $splitTargets[] = $mid;
            }
            $splitTargets = array_values(array_unique($splitTargets));
            if ($splitTargets === []) {
                Response::error('At least one split member is required', 422);
            }
        }

        if ($categoryName !== null && $categoryName === '') {
            $categoryName = null;
        }
        if ($categoryId !== null && $categoryId === '') {
            $categoryId = null;
        }
        if ($categoryName !== null && mb_strlen($categoryName) > 100) {
            Response::error('category_name must be 100 characters or fewer', 422);
        }

        $splits = $this->buildSplits($splitTargets, $allMembers, $amountValue, $splitMap);

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare(
                'INSERT INTO expenses (
                    trip_id, title, amount, paid_by_member_id, created_by_user_id,
                    category_id, category_name, is_settled, created_at
                 ) VALUES (
                    :trip_id, :title, :amount, :paid_by_member_id, :created_by_user_id,
                    :category_id, :category_name, 0, :created_at
                 )'
            );
            $stmt->execute([
                'trip_id' => $id,
                'title' => $title,
                'amount' => $amountValue,
                'paid_by_member_id' => $paidByMemberId,
                'created_by_user_id' => (int) $user['id'],
                'category_id' => $categoryId,
                'category_name' => $categoryName,
                'created_at' => gmdate('Y-m-d H:i:s'),
            ]);

            $expenseId = (int) $this->db->lastInsertId();

            $splitStmt = $this->db->prepare(
                'INSERT INTO expense_splits (expense_id, member_id, amount) VALUES (:expense_id, :member_id, :amount)'
            );

            foreach ($splits as $memberId => $splitAmount) {
                $splitStmt->execute([
                    'expense_id' => $expenseId,
                    'member_id' => $memberId,
                    'amount' => $splitAmount,
                ]);
            }

            $this->db->commit();
        } catch (PDOException $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            // Fallback without category columns if migration not yet applied
            if (str_contains(strtolower($e->getMessage()), 'unknown column')
                || str_contains(strtolower($e->getMessage()), 'no such column')) {
                $this->createLegacyExpense($id, $title, $amountValue, $paidByMemberId, (int) $user['id'], $splits);
                return;
            }
            Response::error('Failed to create expense: ' . $e->getMessage(), 500);
        }

        $expense = $this->fetchExpenseById($expenseId);
        Response::success($expense, 201);
    }

    /**
     * @param array<int, float> $splits
     */
    private function createLegacyExpense(
        int $tripId,
        string $title,
        float $amountValue,
        int $paidByMemberId,
        int $userId,
        array $splits
    ): void {
        try {
            $this->db->beginTransaction();
            $stmt = $this->db->prepare(
                'INSERT INTO expenses (trip_id, title, amount, paid_by_member_id, created_by_user_id, created_at)
                 VALUES (:trip_id, :title, :amount, :paid_by_member_id, :created_by_user_id, :created_at)'
            );
            $stmt->execute([
                'trip_id' => $tripId,
                'title' => $title,
                'amount' => $amountValue,
                'paid_by_member_id' => $paidByMemberId,
                'created_by_user_id' => $userId,
                'created_at' => gmdate('Y-m-d H:i:s'),
            ]);
            $expenseId = (int) $this->db->lastInsertId();
            $splitStmt = $this->db->prepare(
                'INSERT INTO expense_splits (expense_id, member_id, amount) VALUES (:expense_id, :member_id, :amount)'
            );
            foreach ($splits as $memberId => $splitAmount) {
                $splitStmt->execute([
                    'expense_id' => $expenseId,
                    'member_id' => $memberId,
                    'amount' => $splitAmount,
                ]);
            }
            $this->db->commit();
        } catch (PDOException $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            Response::error('Failed to create expense', 500);
        }

        $expense = $this->fetchExpenseById($expenseId);
        Response::success($expense, 201);
    }

    public function delete(string $tripId, string $expenseId): void
    {
        $user = Auth::requireUser($this->db);
        $trip = (int) $tripId;
        $expense = (int) $expenseId;
        $userId = (int) $user['id'];

        if (!$this->userIsMember($trip, $userId)) {
            Response::error('Trip not found', 404);
        }

        $stmt = $this->db->prepare(
            'SELECT e.id, e.created_by_user_id, t.owner_id
             FROM expenses e
             INNER JOIN trips t ON t.id = e.trip_id
             WHERE e.id = :expense_id AND e.trip_id = :trip_id
             LIMIT 1'
        );
        $stmt->execute(['expense_id' => $expense, 'trip_id' => $trip]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Expense not found', 404);
        }

        $isCreator = (int) $row['created_by_user_id'] === $userId;
        $isOwner = (int) $row['owner_id'] === $userId;
        if (!$isCreator && !$isOwner) {
            Response::error('Only the expense creator or trip owner can delete this expense', 403);
        }

        $delete = $this->db->prepare('DELETE FROM expenses WHERE id = :id');
        $delete->execute(['id' => $expense]);

        Response::success(['deleted' => true, 'expense_id' => $expense]);
    }

    /**
     * @param array<int, int> $splitTargets
     * @param array<int, int> $allMemberIds
     * @return array<int, float>
     */
    private function buildSplits(array $splitTargets, array $allMemberIds, float $amount, mixed $splitMap): array
    {
        if ($splitMap === null) {
            return $this->splitEqually($splitTargets, $amount);
        }

        if (!is_array($splitMap)) {
            Response::error('split must be an object/map of member_id => amount', 422);
        }

        $splits = [];
        $total = 0.0;

        foreach ($splitMap as $memberId => $splitAmount) {
            if (!is_numeric($memberId)) {
                Response::error('split keys must be member IDs', 422);
            }

            $memberId = (int) $memberId;
            if (!in_array($memberId, $allMemberIds, true)) {
                Response::error("Member {$memberId} is not part of this trip", 422);
            }

            if (!is_numeric($splitAmount) || (float) $splitAmount < 0) {
                Response::error('split amounts must be non-negative numbers', 422);
            }

            $value = round((float) $splitAmount, 2);
            if ($value <= 0) {
                continue;
            }
            $splits[$memberId] = $value;
            $total += $value;
        }

        if ($splits === []) {
            Response::error('At least one positive split is required', 422);
        }

        if (abs($total - $amount) > 0.01) {
            Response::error('split amounts must sum to the expense amount', 422);
        }

        return $splits;
    }

    /**
     * @param array<int, int> $memberIds
     * @return array<int, float>
     */
    private function splitEqually(array $memberIds, float $amount): array
    {
        $count = count($memberIds);
        $base = floor(($amount / $count) * 100) / 100;
        $allocated = $base * $count;
        $remainderCents = (int) round(($amount - $allocated) * 100);

        $splits = [];
        foreach ($memberIds as $index => $memberId) {
            $extra = $index < $remainderCents ? 0.01 : 0.0;
            $splits[$memberId] = round($base + $extra, 2);
        }

        return $splits;
    }

    private function userIsMember(int $tripId, int $userId): bool
    {
        $stmt = $this->db->prepare(
            'SELECT 1 FROM trip_members WHERE trip_id = :trip_id AND user_id = :user_id LIMIT 1'
        );
        $stmt->execute(['trip_id' => $tripId, 'user_id' => $userId]);

        return (bool) $stmt->fetchColumn();
    }

    private function memberBelongsToTrip(int $tripId, int $memberId): bool
    {
        $stmt = $this->db->prepare(
            'SELECT 1 FROM trip_members WHERE trip_id = :trip_id AND id = :member_id LIMIT 1'
        );
        $stmt->execute(['trip_id' => $tripId, 'member_id' => $memberId]);

        return (bool) $stmt->fetchColumn();
    }

    /**
     * @return array<int, int>
     */
    private function fetchMemberIds(int $tripId): array
    {
        $stmt = $this->db->prepare('SELECT id FROM trip_members WHERE trip_id = :trip_id ORDER BY id ASC');
        $stmt->execute(['trip_id' => $tripId]);

        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }

    private function fetchExpenseById(int $expenseId): ?array
    {
        $expenses = $this->fetchExpensesByIds([$expenseId]);

        return $expenses[0] ?? null;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchExpenses(int $tripId): array
    {
        $stmt = $this->db->prepare(
            'SELECT e.id
             FROM expenses e
             WHERE e.trip_id = :trip_id
             ORDER BY e.created_at DESC, e.id DESC'
        );
        $stmt->execute(['trip_id' => $tripId]);
        $ids = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

        return $this->fetchExpensesByIds($ids);
    }

    /**
     * @param array<int, int> $expenseIds
     * @return array<int, array<string, mixed>>
     */
    private function fetchExpensesByIds(array $expenseIds): array
    {
        if ($expenseIds === []) {
            return [];
        }

        $placeholders = implode(',', array_fill(0, count($expenseIds), '?'));
        $stmt = $this->db->prepare(
            "SELECT e.id, e.trip_id, e.title, e.amount, e.paid_by_member_id, e.created_by_user_id, e.created_at,
                    e.category_id, e.category_name, COALESCE(e.is_settled, 0) AS is_settled, e.settled_at,
                    COALESCE(NULLIF(pm.display_name, ''), up.display_name, 'Member') AS paid_by_display_name,
                    COALESCE(uc.display_name, 'Member') AS created_by_display_name
             FROM expenses e
             INNER JOIN trip_members pm ON pm.id = e.paid_by_member_id
             LEFT JOIN users up ON up.id = pm.user_id
             LEFT JOIN users uc ON uc.id = e.created_by_user_id
             WHERE e.id IN ($placeholders)
             ORDER BY e.created_at DESC, e.id DESC"
        );
        try {
            $stmt->execute($expenseIds);
            $expenses = $stmt->fetchAll();
        } catch (PDOException) {
            // Pre-migration schema without category/settled columns
            $stmt = $this->db->prepare(
                "SELECT e.id, e.trip_id, e.title, e.amount, e.paid_by_member_id, e.created_by_user_id, e.created_at,
                        COALESCE(NULLIF(pm.display_name, ''), up.display_name, 'Member') AS paid_by_display_name,
                        COALESCE(uc.display_name, 'Member') AS created_by_display_name
                 FROM expenses e
                 INNER JOIN trip_members pm ON pm.id = e.paid_by_member_id
                 LEFT JOIN users up ON up.id = pm.user_id
                 LEFT JOIN users uc ON uc.id = e.created_by_user_id
                 WHERE e.id IN ($placeholders)
                 ORDER BY e.created_at DESC, e.id DESC"
            );
            $stmt->execute($expenseIds);
            $expenses = $stmt->fetchAll();
        }

        $result = [];
        foreach ($expenses as $expense) {
            $splitStmt = $this->db->prepare(
                "SELECT s.member_id, s.amount,
                        COALESCE(NULLIF(m.display_name, ''), u.display_name, 'Member') AS display_name
                 FROM expense_splits s
                 INNER JOIN trip_members m ON m.id = s.member_id
                 LEFT JOIN users u ON u.id = m.user_id
                 WHERE s.expense_id = :expense_id
                 ORDER BY s.member_id ASC"
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
                'category_id' => isset($expense['category_id']) && $expense['category_id'] !== null
                    ? (string) $expense['category_id'] : null,
                'category_name' => $expense['category_name'] ?? null,
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

    private function formatMoney(mixed $value): string
    {
        return number_format((float) $value, 2, '.', '');
    }
}
