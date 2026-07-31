<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\Json;
use App\Support\Money;
use App\View;

/**
 * Seller dashboard: order fulfillment queue + product CRUD — mirrors the reference app's
 * `/seller`, `/seller/products/new`, `/seller/products/[id]/edit`. Gated on
 * `customRole === "seller"` for UX only; the real security boundary is Mudbase's own
 * collection-permission enforcement (see README "Security").
 */
final class SellerController
{
    /** Only "paid" and "shipped" have a next manual step — same map as SellerOrderQueue.tsx. */
    private const NEXT_STATUS = [
        'paid' => 'shipped',
        'shipped' => 'delivered',
    ];

    /** @param array<string, string> $params */
    public function dashboard(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();

        $ordersError = null;
        $orders = [];
        try {
            $result = $ctx->mudbase->listDocuments($ctx->ordersCollectionId, null, '-createdAt', 1, 100);
            $orders = $result['data'];
        } catch (MudbaseApiError $e) {
            $ordersError = $e->getMessage();
        }

        $productsError = null;
        $products = [];
        try {
            $result = $ctx->mudbase->listDocuments($ctx->productsCollectionId, null, '-createdAt', 1, 100);
            $products = $result['data'];
        } catch (MudbaseApiError $e) {
            $productsError = $e->getMessage();
        }

        View::render('seller_dashboard', [
            'orders' => $orders,
            'ordersError' => $ordersError,
            'products' => $products,
            'productsError' => $productsError,
        ]);
    }

    /**
     * No Socket.IO client here (see README "Known limitations" — no realtime in the PHP
     * reimplementation); public/assets/seller-poll.js short-polls this endpoint every few seconds
     * and swaps the queue container's HTML with the response instead.
     *
     * @param array<string, string> $params
     */
    public function ordersFragment(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();

        $orders = [];
        $error = null;
        try {
            $result = $ctx->mudbase->listDocuments($ctx->ordersCollectionId, null, '-createdAt', 1, 100);
            $orders = $result['data'];
        } catch (MudbaseApiError $e) {
            $error = $e->getMessage();
        }

        header('Content-Type: text/html; charset=utf-8');
        echo View::renderPartial('partials/seller_order_queue', ['orders' => $orders, 'ordersError' => $error]);
        exit;
    }

    /** @param array{id: string} $params */
    public function advanceOrder(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();
        $this->requireCsrf('/seller');

        try {
            $order = $ctx->mudbase->getDocument($ctx->ordersCollectionId, $params['id']);
            $current = (string) ($order['orderStatus'] ?? '');
            $next = self::NEXT_STATUS[$current] ?? null;
            if ($next !== null) {
                $ctx->mudbase->updateDocument($ctx->ordersCollectionId, $params['id'], ['orderStatus' => $next]);
            }
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't update that order: {$e->getMessage()}");
        }

        Response::redirect('/seller');
    }

    /** @param array<string, string> $params */
    public function newProductForm(array $params): void
    {
        $this->requireSeller();
        View::render('seller_product_form', [
            'product' => null,
            'formAction' => '/seller/products/new',
            'heading' => 'Add product',
        ]);
    }

    /** @param array<string, string> $params */
    public function createProduct(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();
        $this->requireCsrf('/seller/products/new');

        [$fields, $errors] = $this->readProductForm();
        if ($errors !== []) {
            Flash::set('error', implode(' ', $errors));
            Response::redirect('/seller/products/new');
        }

        $slug = Money::slugify((string) $fields['name']) . '-' . substr(bin2hex(random_bytes(4)), 0, 6);

        try {
            $ctx->mudbase->createDocument($ctx->productsCollectionId, [
                ...$fields,
                'slug' => $slug,
                'sellerId' => $ctx->userId(),
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't save that product: {$e->getMessage()}");
            Response::redirect('/seller/products/new');
        }

        Flash::set('success', 'Product created.');
        Response::redirect('/seller');
    }

    /** @param array{id: string} $params */
    public function editProductForm(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();

        try {
            $product = $ctx->mudbase->getDocument($ctx->productsCollectionId, $params['id']);
        } catch (MudbaseApiError $e) {
            View::render('seller_product_form', [
                'product' => null,
                'error' => $e->getMessage(),
                'formAction' => "/seller/products/{$params['id']}/edit",
                'heading' => 'Edit product',
            ], 404);
            return;
        }

        View::render('seller_product_form', [
            'product' => $product,
            'formAction' => "/seller/products/{$params['id']}/edit",
            'heading' => 'Edit product',
        ]);
    }

    /** @param array{id: string} $params */
    public function updateProduct(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();
        $this->requireCsrf("/seller/products/{$params['id']}/edit");

        [$fields, $errors] = $this->readProductForm();
        if ($errors !== []) {
            Flash::set('error', implode(' ', $errors));
            Response::redirect("/seller/products/{$params['id']}/edit");
        }

        try {
            $ctx->mudbase->updateDocument($ctx->productsCollectionId, $params['id'], $fields);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't save that product: {$e->getMessage()}");
            Response::redirect("/seller/products/{$params['id']}/edit");
        }

        Flash::set('success', 'Product updated.');
        Response::redirect('/seller');
    }

    /** @param array{id: string} $params */
    public function deleteProduct(array $params): void
    {
        $this->requireSeller();
        $ctx = AppContext::current();
        $this->requireCsrf('/seller');

        try {
            $ctx->mudbase->deleteDocument($ctx->productsCollectionId, $params['id']);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't delete that product: {$e->getMessage()}");
        }

        Response::redirect('/seller');
    }

    /**
     * Reads and validates the shared product form fields (create + edit use the same set).
     *
     * @return array{0: array<string, mixed>, 1: list<string>}
     */
    private function readProductForm(): array
    {
        $errors = [];

        $name = trim((string) ($_POST['name'] ?? ''));
        if ($name === '') {
            $errors[] = 'Name is required.';
        }

        $priceCents = (int) ($_POST['priceCents'] ?? -1);
        if ($priceCents < 0) {
            $errors[] = "Price can't be negative.";
        }

        $stock = (int) ($_POST['stock'] ?? -1);
        if ($stock < 0) {
            $errors[] = "Stock can't be negative.";
        }

        $compareAtRaw = trim((string) ($_POST['compareAtPriceCents'] ?? ''));
        $compareAtPriceCents = null;
        if ($compareAtRaw !== '') {
            $compareAtPriceCents = (int) $compareAtRaw;
            if ($compareAtPriceCents <= $priceCents) {
                $errors[] = 'Compare-at price must be higher than the current price.';
            }
        }

        $imageUrl = trim((string) ($_POST['imageUrl'] ?? ''));
        if ($imageUrl !== '' && filter_var($imageUrl, FILTER_VALIDATE_URL) === false) {
            $errors[] = 'Main image must be a valid URL.';
        }

        $galleryRaw = (string) ($_POST['galleryUrls'] ?? '');
        $galleryUrls = [];
        foreach (preg_split('/\r\n|\r|\n/', $galleryRaw) ?: [] as $line) {
            $line = trim($line);
            if ($line === '') {
                continue;
            }
            if (filter_var($line, FILTER_VALIDATE_URL) === false) {
                $errors[] = "Additional photo URL isn't valid: {$line}";
                continue;
            }
            $galleryUrls[] = $line;
        }
        $galleryUrls = array_slice($galleryUrls, 0, 8);

        $fields = [
            'name' => $name,
            'description' => trim((string) ($_POST['description'] ?? '')),
            'priceCents' => max(0, $priceCents),
            'currency' => trim((string) ($_POST['currency'] ?? 'USD')) ?: 'USD',
            'imageUrl' => $imageUrl !== '' ? $imageUrl : null,
            'galleryJson' => Json::stringifyField($galleryUrls),
            'category' => trim((string) ($_POST['category'] ?? '')) ?: null,
            'stock' => max(0, $stock),
            'isActive' => ($_POST['isActive'] ?? null) === 'on',
        ];
        if ($compareAtPriceCents !== null) {
            $fields['compareAtPriceCents'] = $compareAtPriceCents;
        }

        return [$fields, $errors];
    }

    private function requireSeller(): void
    {
        if (!AppContext::current()->isSeller()) {
            Flash::set('error', "You don't have access to the seller dashboard.");
            Response::redirect('/');
        }
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
