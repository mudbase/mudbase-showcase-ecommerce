<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\Json;
use App\View;

/** Order history + detail — mirrors the reference app's `/orders` and `/orders/[id]`. */
final class OrderController
{
    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        if (!$ctx->isCustomer()) {
            Flash::set('error', 'Sign in to view your orders.');
            Response::redirect('/login?redirect=/orders');
        }

        $error = null;
        $orders = [];
        try {
            $result = $ctx->mudbase->listDocuments($ctx->ordersCollectionId, ['userId' => $ctx->userId()], '-createdAt', 1, 50);
            $orders = $result['data'];
        } catch (MudbaseApiError $e) {
            $error = $e->getMessage();
        }

        View::render('orders_index', ['orders' => $orders, 'error' => $error]);
    }

    /** @param array{id: string} $params */
    public function show(array $params): void
    {
        $ctx = AppContext::current();

        $order = null;
        $error = null;
        try {
            $order = $ctx->mudbase->getDocument($ctx->ordersCollectionId, $params['id']);
        } catch (MudbaseApiError $e) {
            $error = $e->getMessage();
        }

        // Mudbase's ownership condition on `orders` already enforces this server-side (a customer
        // can only ever successfully read their own order); this check exists purely so a
        // logged-in customer who guesses another shopper's order id gets the same honest "not
        // found" the reference app shows, not a raw permission-denied error.
        if ($order !== null && !$ctx->isSeller() && ($order['userId'] ?? null) !== $ctx->userId()) {
            $order = null;
        }

        if ($order === null) {
            View::render('order_detail', ['order' => null, 'error' => $error], 404);
            return;
        }

        $items = Json::parseField($order['itemsJson'] ?? null, []);
        $address = Json::parseField($order['shippingAddressJson'] ?? null, null);

        View::render('order_detail', [
            'order' => $order,
            'items' => $items,
            'address' => $address,
            'error' => null,
        ]);
    }
}
