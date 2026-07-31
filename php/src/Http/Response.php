<?php

declare(strict_types=1);

namespace App\Http;

/**
 * Tiny response helpers shared by every controller — redirects and JSON output (used only by the
 * seller order-queue short-poll endpoint, see public "Known limitations" re: no Socket.IO client).
 */
final class Response
{
    public static function redirect(string $path): never
    {
        header('Location: ' . $path, true, 303);
        exit;
    }

    /** @param array<string, mixed> $data */
    public static function json(array $data, int $statusCode = 200): never
    {
        http_response_code($statusCode);
        header('Content-Type: application/json');
        echo json_encode($data, JSON_UNESCAPED_SLASHES);
        exit;
    }
}
