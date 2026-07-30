<?php

declare(strict_types=1);

namespace Inpenso;

final class Response
{
    /** Max JSON request body size (2 MiB — ledger sync payloads). */
    public const MAX_BODY_BYTES = 2097152;

    public static function json(mixed $data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function success(mixed $data = null, int $status = 200): void
    {
        self::json(['ok' => true, 'data' => $data], $status);
    }

    public static function error(string $message, int $status = 400, ?string $code = null): void
    {
        $payload = ['ok' => false, 'error' => $message];
        if ($code !== null && $code !== '') {
            $payload['code'] = $code;
        }
        self::json($payload, $status);
    }

    public static function applyCors(array $corsConfig): void
    {
        $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
        $allowed = $corsConfig['allowed_origins'] ?? ['*'];

        if (in_array('*', $allowed, true)) {
            header('Access-Control-Allow-Origin: *');
        } elseif ($origin !== '' && in_array($origin, $allowed, true)) {
            header('Access-Control-Allow-Origin: ' . $origin);
            header('Vary: Origin');
        }

        header('Access-Control-Allow-Methods: ' . ($corsConfig['allowed_methods'] ?? 'GET, POST, PUT, DELETE, OPTIONS'));
        header('Access-Control-Allow-Headers: ' . ($corsConfig['allowed_headers'] ?? 'Content-Type, Authorization, X-API-Token'));
        header('Access-Control-Max-Age: ' . (string) ($corsConfig['max_age'] ?? 86400));

        if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
            http_response_code(204);
            exit;
        }
    }

    public static function readJsonBody(): array
    {
        $contentLength = $_SERVER['CONTENT_LENGTH'] ?? null;
        if ($contentLength !== null && $contentLength !== '' && (int) $contentLength > self::MAX_BODY_BYTES) {
            self::error('Request body too large', 413);
        }

        $raw = file_get_contents('php://input', false, null, 0, self::MAX_BODY_BYTES + 1);
        if ($raw === false) {
            return [];
        }

        if (strlen($raw) > self::MAX_BODY_BYTES) {
            self::error('Request body too large', 413);
        }

        if (trim($raw) === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            self::error('Invalid JSON body', 400);
        }

        return $decoded;
    }
}
