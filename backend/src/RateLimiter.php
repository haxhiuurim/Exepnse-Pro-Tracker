<?php

declare(strict_types=1);

namespace Inpenso;

/**
 * Simple file-based rate limiter for shared hosting (no Redis required).
 */
final class RateLimiter
{
    public static function enforce(string $bucket, int $maxAttempts, int $windowSeconds): void
    {
        $ip = self::clientIp();
        $key = $bucket . ':' . $ip;
        $dir = dirname(__DIR__) . '/storage/rate_limits';

        if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
            return;
        }

        $path = $dir . '/' . hash('sha256', $key) . '.json';
        $now = time();
        $attempts = [];

        if (is_readable($path)) {
            $raw = file_get_contents($path);
            $decoded = is_string($raw) ? json_decode($raw, true) : null;
            if (is_array($decoded)) {
                $attempts = array_values(array_filter(
                    $decoded,
                    static fn ($ts): bool => is_int($ts) && $ts > ($now - $windowSeconds)
                ));
            }
        }

        if (count($attempts) >= $maxAttempts) {
            Response::error('Too many requests. Please try again later.', 429);
        }

        $attempts[] = $now;
        file_put_contents($path, json_encode($attempts), LOCK_EX);
    }

    public static function clientIp(): string
    {
        $candidates = [
            $_SERVER['HTTP_X_REAL_IP'] ?? null,
            $_SERVER['HTTP_CF_CONNECTING_IP'] ?? null,
        ];

        $forwarded = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
        if ($forwarded !== '') {
            $parts = array_map('trim', explode(',', $forwarded));
            if ($parts[0] !== '') {
                array_unshift($candidates, $parts[0]);
            }
        }

        foreach ($candidates as $candidate) {
            if (!is_string($candidate) || $candidate === '') {
                continue;
            }
            if (filter_var($candidate, FILTER_VALIDATE_IP)) {
                return $candidate;
            }
        }

        $remote = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
        return filter_var($remote, FILTER_VALIDATE_IP) ? $remote : '0.0.0.0';
    }
}
