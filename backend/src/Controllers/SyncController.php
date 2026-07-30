<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\Auth;
use Inpenso\Response;
use Inpenso\UserActivity;
use PDO;

/**
 * Personal ledger sync.
 *
 * Document types mirror the iOS app stores:
 * expenses, budgets, category_budgets, recurring, accounts, goals, debts,
 * merchant_rules, category_catalog, settings, trip_shortcuts
 */
final class SyncController
{
    public const DOC_TYPES = [
        'expenses',
        'budgets',
        'category_budgets',
        'recurring',
        'accounts',
        'goals',
        'debts',
        'merchant_rules',
        'category_catalog',
        'settings',
        'trip_shortcuts',
    ];

    public function __construct(private PDO $db)
    {
    }

    public function pull(): void
    {
        $user = Auth::requireUser($this->db);
        $userId = (int) $user['id'];

        $stmt = $this->db->prepare(
            'SELECT doc_type, payload, updated_at FROM sync_documents WHERE user_id = :user_id'
        );
        $stmt->execute(['user_id' => $userId]);

        $docs = [];
        $latest = null;
        foreach ($stmt->fetchAll() as $row) {
            $decoded = json_decode((string) $row['payload'], true);
            $docs[$row['doc_type']] = $decoded ?? [];
            if ($latest === null || $row['updated_at'] > $latest) {
                $latest = $row['updated_at'];
            }
        }

        foreach (self::DOC_TYPES as $type) {
            if (!array_key_exists($type, $docs)) {
                $docs[$type] = [];
            }
        }

        Response::success([
            'updated_at' => $latest,
            'documents' => $docs,
            'user' => [
                'user_id' => $userId,
                'email' => $user['email'] ?? null,
                'display_name' => $user['display_name'],
            ],
        ]);
    }

    public function push(): void
    {
        $user = Auth::requireUser($this->db);
        $userId = (int) $user['id'];
        $body = Response::readJsonBody();
        $documents = $body['documents'] ?? null;

        if (!is_array($documents)) {
            Response::error('documents object is required', 422);
        }

        $now = gmdate('Y-m-d H:i:s');
        $upsert = $this->db->prepare(
            'INSERT INTO sync_documents (user_id, doc_type, payload, updated_at)
             VALUES (:user_id, :doc_type, :payload, :updated_at)
             ON CONFLICT(user_id, doc_type) DO UPDATE SET
                payload = excluded.payload,
                updated_at = excluded.updated_at'
        );

        // MySQL-compatible upsert fallback if SQLite ON CONFLICT unsupported in older envs
        $mysqlUpsert = $this->db->prepare(
            'INSERT INTO sync_documents (user_id, doc_type, payload, updated_at)
             VALUES (:user_id, :doc_type, :payload, :updated_at)
             ON DUPLICATE KEY UPDATE payload = VALUES(payload), updated_at = VALUES(updated_at)'
        );

        $this->db->beginTransaction();
        try {
            foreach ($documents as $type => $payload) {
                $type = (string) $type;
                if (!in_array($type, self::DOC_TYPES, true)) {
                    continue;
                }
                $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
                if ($json === false) {
                    throw new \RuntimeException('Invalid JSON for ' . $type);
                }

                $params = [
                    'user_id' => $userId,
                    'doc_type' => $type,
                    'payload' => $json,
                    'updated_at' => $now,
                ];

                try {
                    $upsert->execute($params);
                } catch (\PDOException) {
                    $mysqlUpsert->execute($params);
                }
            }
            $this->db->commit();
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            Response::error('Sync failed: ' . $e->getMessage(), 500);
        }

        UserActivity::touchData($this->db, $userId);
        Response::success(['updated_at' => $now, 'saved' => true]);
    }
}
