<?php

declare(strict_types=1);

namespace Inpenso\Controllers;

use Inpenso\AppConfig;
use Inpenso\Response;
use PDO;

final class ConfigController
{
    public function __construct(private PDO $db)
    {
    }

    public function publicConfig(): void
    {
        Response::success(AppConfig::publicPayload($this->db));
    }
}
