<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Formatting + numeric helpers mirroring the reference Next.js app's src/lib/utils.ts, kept in
 * one small module rather than scattered inline across views (many small files > few large files).
 */
final class Money
{
    /** @var array<string, string> Currency symbols for the handful this storefront ever displays. */
    private const SYMBOLS = [
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£',
    ];

    /**
     * Deliberately does not depend on ext-intl (not guaranteed present on every deploy target,
     * and this app must boot with nothing more than `composer install`) — a small symbol table
     * covers every currency this demo ever renders (USD for prices, USDC for the payment link).
     */
    public static function format(int $cents, string $currency = 'USD'): string
    {
        $amount = number_format($cents / 100, 2);
        $symbol = self::SYMBOLS[$currency] ?? null;
        return $symbol !== null ? "{$symbol}{$amount}" : "{$amount} {$currency}";
    }

    public static function formatDate(string $iso): string
    {
        try {
            $date = new \DateTimeImmutable($iso);
        } catch (\Exception) {
            return $iso;
        }
        return $date->format('M j, Y g:i A');
    }

    public static function slugify(string $value): string
    {
        $lower = strtolower(trim($value));
        $slug = preg_replace('/[^a-z0-9]+/', '-', $lower) ?? $lower;
        return trim($slug, '-');
    }

    public static function discountPercent(int $priceCents, ?int $compareAtPriceCents): ?int
    {
        if ($compareAtPriceCents === null || $compareAtPriceCents <= $priceCents) {
            return null;
        }
        return (int) round((1 - $priceCents / $compareAtPriceCents) * 100);
    }
}
