<?php

declare(strict_types=1);

namespace App\Support;

use App\Mudbase\MudbaseClient;

/**
 * Mirrors the reference Next.js app's src/hooks/useCart.ts: the `carts` collection's ownership
 * condition only grants create/read/update/delete to the `customer` application role (see
 * plan/build-plan.md), so a guest (anonymous session, customRole null) cannot persist a cart there
 * at all. The web app keeps a guest cart in browser localStorage until a real customer account
 * exists, then migrates it server-side. This server-rendered app has no client-side storage to
 * reach for, so the native PHP session (`$_SESSION['guest_cart']`) plays the same role — same
 * one-guest-cart-until-signup shape, just persisted server-side instead of in the browser.
 */
final class Cart
{
    private const GUEST_CART_SESSION_KEY = 'guest_cart';

    public function __construct(
        private readonly MudbaseClient $client,
        private readonly string $cartsCollectionId,
    ) {
    }

    /**
     * @param array<string, mixed>|null $user
     * @return list<array<string, mixed>>
     */
    public function itemsFor(?array $user): array
    {
        if (self::isCustomer($user)) {
            $doc = $this->findServerCart((string) $user['id']);
            return $doc !== null ? Json::parseField($doc['itemsJson'] ?? null, []) : [];
        }
        return $_SESSION[self::GUEST_CART_SESSION_KEY] ?? [];
    }

    public static function subtotalCents(array $items): int
    {
        $sum = 0;
        foreach ($items as $item) {
            $sum += (int) ($item['priceCents'] ?? 0) * (int) ($item['quantity'] ?? 0);
        }
        return $sum;
    }

    /**
     * @param array<string, mixed>|null $user
     * @param array{productId: string, name: string, priceCents: int, currency: string, imageUrl: ?string} $item
     * @return list<array<string, mixed>>
     */
    public function addItem(?array $user, array $item, int $quantity = 1): array
    {
        $items = $this->itemsFor($user);
        $existingIndex = self::findIndex($items, $item['productId']);

        if ($existingIndex !== null) {
            $items[$existingIndex]['quantity'] = (int) $items[$existingIndex]['quantity'] + $quantity;
        } else {
            $items[] = [...$item, 'quantity' => $quantity];
        }

        return $this->persist($user, $items);
    }

    /**
     * @param array<string, mixed>|null $user
     * @return list<array<string, mixed>>
     */
    public function updateQuantity(?array $user, string $productId, int $quantity): array
    {
        $items = $this->itemsFor($user);

        if ($quantity <= 0) {
            $items = array_values(array_filter($items, fn (array $i): bool => $i['productId'] !== $productId));
        } else {
            foreach ($items as $index => $existing) {
                if ($existing['productId'] === $productId) {
                    $items[$index]['quantity'] = $quantity;
                }
            }
        }

        return $this->persist($user, $items);
    }

    /**
     * @param array<string, mixed>|null $user
     * @return list<array<string, mixed>>
     */
    public function removeItem(?array $user, string $productId): array
    {
        $items = $this->itemsFor($user);
        $items = array_values(array_filter($items, fn (array $i): bool => $i['productId'] !== $productId));
        return $this->persist($user, $items);
    }

    /**
     * @param array<string, mixed>|null $user
     */
    public function clear(?array $user): void
    {
        $this->persist($user, []);
    }

    /**
     * Called once, right after a guest's registration/login succeeds — merges the PHP-session
     * guest cart into that customer's server cart, same read-then-merge-then-create-or-update
     * shape as the reference app's migrateGuestCartToServer() (a returning customer signing back
     * in may already have a server cart from an earlier session; blindly creating a new one would
     * duplicate it instead of merging).
     *
     * @param array<string, mixed> $user
     */
    public function migrateGuestCartToServer(array $user): void
    {
        $guestItems = $_SESSION[self::GUEST_CART_SESSION_KEY] ?? [];
        if ($guestItems === []) {
            return;
        }

        $userId = (string) $user['id'];
        $existing = $this->findServerCart($userId);

        if ($existing === null) {
            $this->client->createDocument($this->cartsCollectionId, [
                'userId' => $userId,
                'itemsJson' => Json::stringifyField($guestItems),
            ]);
            $_SESSION[self::GUEST_CART_SESSION_KEY] = [];
            return;
        }

        $existingItems = Json::parseField($existing['itemsJson'] ?? null, []);
        $merged = $existingItems;
        foreach ($guestItems as $guestItem) {
            $index = self::findIndex($merged, $guestItem['productId']);
            if ($index !== null) {
                $merged[$index]['quantity'] = (int) $merged[$index]['quantity'] + (int) $guestItem['quantity'];
            } else {
                $merged[] = $guestItem;
            }
        }

        $this->client->updateDocument($this->cartsCollectionId, (string) $existing['_id'], [
            'itemsJson' => Json::stringifyField($merged),
        ]);
        $_SESSION[self::GUEST_CART_SESSION_KEY] = [];
    }

    /**
     * @param array<string, mixed>|null $user
     * @param list<array<string, mixed>> $items
     * @return list<array<string, mixed>>
     */
    private function persist(?array $user, array $items): array
    {
        if (!self::isCustomer($user)) {
            $_SESSION[self::GUEST_CART_SESSION_KEY] = $items;
            return $items;
        }

        $userId = (string) $user['id'];
        $itemsJson = Json::stringifyField($items);
        $existing = $this->findServerCart($userId);

        if ($existing !== null) {
            $this->client->updateDocument($this->cartsCollectionId, (string) $existing['_id'], ['itemsJson' => $itemsJson]);
        } else {
            $this->client->createDocument($this->cartsCollectionId, ['userId' => $userId, 'itemsJson' => $itemsJson]);
        }

        return $items;
    }

    /** @return array<string, mixed>|null */
    private function findServerCart(string $userId): ?array
    {
        $result = $this->client->listDocuments($this->cartsCollectionId, ['userId' => $userId], limit: 1);
        return $result['data'][0] ?? null;
    }

    /** @param array<string, mixed>|null $user */
    private static function isCustomer(?array $user): bool
    {
        return $user !== null && ($user['customRole'] ?? null) === 'customer';
    }

    /** @param list<array<string, mixed>> $items */
    private static function findIndex(array $items, string $productId): ?int
    {
        foreach ($items as $index => $item) {
            if ($item['productId'] === $productId) {
                return $index;
            }
        }
        return null;
    }
}
