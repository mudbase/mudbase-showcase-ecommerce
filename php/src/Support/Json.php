<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Mudbase Collection fields have a fixed type enum (string, number, boolean, date, email, url,
 * enum, reference) with no native array/object type. Anything shaped like a list or a nested
 * record (order line items, a shipping address, extra product images) is stored as a JSON string
 * in a `string` field and parsed at the edges — a real, documented constraint of the platform's
 * Collections feature (see the reference Next.js app's src/lib/json-field.ts), not a workaround
 * specific to this reimplementation.
 */
final class Json
{
    /**
     * @template T
     * @param T $fallback
     * @return T
     */
    public static function parseField(?string $value, mixed $fallback): mixed
    {
        if ($value === null || $value === '') {
            return $fallback;
        }
        $decoded = json_decode($value, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return $fallback;
        }
        return $decoded;
    }

    public static function stringifyField(mixed $value): string
    {
        $encoded = json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        return $encoded === false ? '[]' : $encoded;
    }
}
