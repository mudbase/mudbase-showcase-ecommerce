<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\Cart;
use App\Support\Json;
use App\View;

/**
 * Checkout + payment — mirrors the reference app's `/checkout` and `/checkout/[token]`. Order
 * creation happens under the signed-in customer's own session (ownership-conditioned `orders`
 * permission); Payment Link creation is delegated to PaymentLinkProxy (see its docblock) because
 * it requires a merchant-level credential this app never holds.
 */
final class CheckoutController
{
    private const CURRENCY = 'USDC';
    private const NETWORK = 'POLYGON';

    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $items = $ctx->cart->itemsFor($ctx->user);

        View::render('checkout', [
            'items' => $items,
            'subtotalCents' => Cart::subtotalCents($items),
            'isCustomer' => $ctx->isCustomer(),
            'authMode' => ($_GET['mode'] ?? 'register') === 'login' ? 'login' : 'register',
        ]);
    }

    /** @param array<string, string> $params */
    public function submit(array $params): void
    {
        $ctx = AppContext::current();
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect('/checkout');
        }

        if (!$ctx->isCustomer()) {
            Flash::set('error', 'Please sign in to complete checkout.');
            Response::redirect('/checkout');
        }

        $items = $ctx->cart->itemsFor($ctx->user);
        if ($items === []) {
            Response::redirect('/cart');
        }

        $address = [
            'fullName' => trim((string) ($_POST['fullName'] ?? '')),
            'line1' => trim((string) ($_POST['line1'] ?? '')),
            'line2' => trim((string) ($_POST['line2'] ?? '')),
            'city' => trim((string) ($_POST['city'] ?? '')),
            'region' => trim((string) ($_POST['region'] ?? '')),
            'postalCode' => trim((string) ($_POST['postalCode'] ?? '')),
            'country' => trim((string) ($_POST['country'] ?? '')),
        ];

        $required = ['fullName', 'line1', 'city', 'region', 'postalCode', 'country'];
        $missing = array_filter($required, fn (string $field): bool => $address[$field] === '');
        if ($missing !== []) {
            Flash::set('error', 'Please fill in every required shipping field.');
            Response::redirect('/checkout');
        }

        $subtotalCents = Cart::subtotalCents($items);
        $orderItems = array_map(static fn (array $item): array => [
            'productId' => $item['productId'],
            'name' => $item['name'],
            'priceCents' => $item['priceCents'],
            'quantity' => $item['quantity'],
        ], $items);

        try {
            $order = $ctx->mudbase->createDocument($ctx->ordersCollectionId, [
                'userId' => $ctx->userId(),
                'itemsJson' => Json::stringifyField($orderItems),
                'subtotalCents' => $subtotalCents,
                'currency' => 'USD',
                'orderStatus' => 'awaiting_payment',
                'shippingName' => $address['fullName'],
                'shippingAddressJson' => Json::stringifyField($address),
                'paymentStatus' => 'unpaid',
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't place your order: {$e->getMessage()}");
            Response::redirect('/checkout');
        }

        $orderId = (string) $order['_id'];
        $amount = number_format($subtotalCents / 100, 2, '.', '');
        $redirectUrl = $this->absoluteUrl("/orders/{$orderId}");

        $result = $ctx->paymentLinkProxy->createForOrder($orderId, $amount, self::CURRENCY, self::NETWORK, $redirectUrl);

        if (!$result['ok']) {
            if ($result['reason'] === 'kyc_required') {
                try {
                    $ctx->mudbase->updateDocument($ctx->ordersCollectionId, $orderId, ['orderStatus' => 'pending']);
                } catch (MudbaseApiError) {
                    // Order still exists as "awaiting_payment" — surfacing the KYC message matters
                    // more than this secondary status tidy-up succeeding.
                }
                Flash::set('error', $result['message']);
                Response::redirect("/orders/{$orderId}");
            }

            Flash::set('error', $result['message']);
            Response::redirect('/checkout');
        }

        $token = (string) ($result['link']['token'] ?? '');
        try {
            $ctx->mudbase->updateDocument($ctx->ordersCollectionId, $orderId, ['paymentLinkToken' => $token]);
        } catch (MudbaseApiError) {
            // Non-fatal — the payment link itself was created; the order just won't carry the
            // token for later lookup from the order-detail "complete payment" link.
        }

        $ctx->cart->clear($ctx->user);
        Response::redirect("/checkout/{$token}");
    }

    /** @param array{token: string} $params */
    public function payment(array $params): void
    {
        $ctx = AppContext::current();
        $link = $ctx->paymentLinkProxy->fetchStatus($params['token']);

        View::render('checkout_payment', [
            'token' => $params['token'],
            'link' => $link,
            'mudbaseUrl' => $ctx->mudbaseUrl,
        ]);
    }

    private function absoluteUrl(string $path): string
    {
        $scheme = (($_SERVER['HTTPS'] ?? '') !== '' && ($_SERVER['HTTPS'] ?? '') !== 'off') ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
        return "{$scheme}://{$host}{$path}";
    }
}
