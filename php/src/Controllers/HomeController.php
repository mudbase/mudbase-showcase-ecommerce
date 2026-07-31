<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Mudbase\MudbaseApiError;
use App\View;

/**
 * Catalog home page — mirrors the reference app's `/` (src/app/page.tsx +
 * components/catalog/ProductGrid.tsx): public `products` collection read, filtered to
 * `isActive: true`, with an optional category pill filter.
 */
final class HomeController
{
    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $category = isset($_GET['category']) && is_string($_GET['category']) && $_GET['category'] !== ''
            ? $_GET['category']
            : null;

        $filter = $category !== null ? ['isActive' => true, 'category' => $category] : ['isActive' => true];

        $error = null;
        $products = [];
        try {
            $result = $ctx->mudbase->listDocuments($ctx->productsCollectionId, $filter, '-createdAt', 1, 60);
            $products = $result['data'];
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load the catalog right now: {$e->getMessage()}";
        }

        // Same derivation as the reference ProductGrid: categories are computed from the
        // currently-loaded (possibly already-filtered) product list, not a separate query.
        $categories = [];
        foreach ($products as $product) {
            $productCategory = $product['category'] ?? null;
            if (is_string($productCategory) && $productCategory !== '' && !in_array($productCategory, $categories, true)) {
                $categories[] = $productCategory;
            }
        }
        sort($categories);

        View::render('home', [
            'products' => $products,
            'categories' => $categories,
            'selectedCategory' => $category,
            'error' => $error,
        ]);
    }
}
