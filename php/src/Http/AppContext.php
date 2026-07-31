<?php

declare(strict_types=1);

namespace App\Http;

use App\Mudbase\MudbaseClient;
use App\Support\Cart;
use App\Support\PaymentLinkProxy;

/**
 * Per-request registry handed to every controller and view: the authenticated Mudbase client,
 * the current session user (or null/anonymous), and the cart helper — the server-rendered
 * counterpart of the reference app's React `useMudbase()` context (src/lib/mudbase-provider.tsx).
 * One instance per request; built once in bootstrap.php right after the session/auth handshake.
 */
final class AppContext
{
    private static ?self $instance = null;

    /** @param array<string, mixed>|null $user */
    public function __construct(
        public readonly MudbaseClient $mudbase,
        public readonly ?array $user,
        public readonly Cart $cart,
        public readonly string $productsCollectionId,
        public readonly string $ordersCollectionId,
        public readonly string $cartsCollectionId,
        public readonly string $mudbaseUrl,
        public readonly PaymentLinkProxy $paymentLinkProxy,
    ) {
    }

    public static function set(self $context): void
    {
        self::$instance = $context;
    }

    public static function current(): self
    {
        if (self::$instance === null) {
            throw new \RuntimeException('AppContext accessed before bootstrap set it.');
        }
        return self::$instance;
    }

    public function isSignedIn(): bool
    {
        // `GET /api/auth/local/session` (see MudbaseClient::fetchSessionUser()) does not reliably
        // return an `isAnonymous` key at all for anonymous sessions in practice — confirmed against
        // the live API, the key is simply absent from the response body — so a bare
        // `($this->user['isAnonymous'] ?? false) !== true` check treats every anonymous guest as
        // signed in (missing key -> false -> "not anonymous"). `customRole` is the reliable signal
        // instead: Mudbase only ever assigns a customRole ("customer"/"seller") to a real
        // registered account; anonymous sessions always come back with `customRole: null`. Kept the
        // `isAnonymous` check too as defense in depth for any response shape that does include it.
        return $this->user !== null
            && ($this->user['isAnonymous'] ?? false) !== true
            && ($this->user['customRole'] ?? null) !== null;
    }

    public function isCustomer(): bool
    {
        return ($this->user['customRole'] ?? null) === 'customer';
    }

    public function isSeller(): bool
    {
        return ($this->user['customRole'] ?? null) === 'seller';
    }

    public function userId(): ?string
    {
        $id = $this->user['id'] ?? $this->user['_id'] ?? null;
        return is_string($id) ? $id : null;
    }

    public function cartItemCount(): int
    {
        $count = 0;
        foreach ($this->cart->itemsFor($this->user) as $item) {
            $count += (int) ($item['quantity'] ?? 0);
        }
        return $count;
    }
}
