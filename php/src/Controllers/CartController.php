<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Support\Cart;
use App\View;

/** Cart page + mutations — mirrors the reference app's `/cart` and `useCart()` hook. */
final class CartController
{
    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $items = $ctx->cart->itemsFor($ctx->user);

        View::render('cart', [
            'items' => $items,
            'subtotalCents' => Cart::subtotalCents($items),
        ]);
    }

    /** @param array<string, string> $params */
    public function add(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf();

        $productId = trim((string) ($_POST['productId'] ?? ''));
        $name = trim((string) ($_POST['name'] ?? ''));
        $priceCents = (int) ($_POST['priceCents'] ?? 0);
        $currency = trim((string) ($_POST['currency'] ?? 'USD'));
        $imageUrl = trim((string) ($_POST['imageUrl'] ?? '')) ?: null;
        $quantity = max(1, (int) ($_POST['quantity'] ?? 1));
        $redirectTo = (string) ($_POST['redirectTo'] ?? '/cart');

        if ($productId === '' || $name === '') {
            Flash::set('error', "Couldn't add that item to your cart.");
            Response::redirect($redirectTo);
        }

        $ctx->cart->addItem($ctx->user, [
            'productId' => $productId,
            'name' => $name,
            'priceCents' => $priceCents,
            'currency' => $currency,
            'imageUrl' => $imageUrl,
        ], $quantity);

        Flash::set('success', 'Added to cart.');
        Response::redirect($redirectTo);
    }

    /** @param array<string, string> $params */
    public function update(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf();

        $productId = trim((string) ($_POST['productId'] ?? ''));
        $quantity = (int) ($_POST['quantity'] ?? 0);
        if ($productId !== '') {
            $ctx->cart->updateQuantity($ctx->user, $productId, $quantity);
        }

        Response::redirect('/cart');
    }

    /** @param array<string, string> $params */
    public function remove(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf();

        $productId = trim((string) ($_POST['productId'] ?? ''));
        if ($productId !== '') {
            $ctx->cart->removeItem($ctx->user, $productId);
        }

        Response::redirect('/cart');
    }

    private function requireCsrf(): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect('/cart');
        }
    }
}
