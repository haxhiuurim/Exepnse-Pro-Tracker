<?php

declare(strict_types=1);

namespace Inpenso;

use Closure;

final class Router
{
    /** @var array<int, array{method: string, pattern: string, handler: Closure}> */
    private array $routes = [];

    public function get(string $pattern, Closure $handler): void
    {
        $this->add('GET', $pattern, $handler);
    }

    public function post(string $pattern, Closure $handler): void
    {
        $this->add('POST', $pattern, $handler);
    }

    public function delete(string $pattern, Closure $handler): void
    {
        $this->add('DELETE', $pattern, $handler);
    }

    private function add(string $method, string $pattern, Closure $handler): void
    {
        $this->routes[] = [
            'method' => strtoupper($method),
            'pattern' => $pattern,
            'handler' => $handler,
        ];
    }

    public function dispatch(string $method, string $uri): void
    {
        $method = strtoupper($method);
        $path = parse_url($uri, PHP_URL_PATH) ?: '/';
        $path = rtrim($path, '/') ?: '/';

        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }

            $params = $this->match($route['pattern'], $path);
            if ($params === null) {
                continue;
            }

            ($route['handler'])(...array_values($params));
            return;
        }

        Response::error('Not found', 404);
    }

    /**
     * @return array<string, string>|null
     */
    private function match(string $pattern, string $path): ?array
    {
        $regex = preg_replace('#\{([a-zA-Z_][a-zA-Z0-9_]*)\}#', '(?P<$1>[^/]+)', $pattern);
        $regex = '#^' . $regex . '$#';

        if (!preg_match($regex, $path, $matches)) {
            return null;
        }

        $params = [];
        foreach ($matches as $key => $value) {
            if (is_string($key)) {
                $params[$key] = $value;
            }
        }

        return $params;
    }
}
