<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Mudbase\MudbaseApiError;
use App\Support\Json;
use App\View;

/** Product detail page — mirrors the reference app's `/products/[slug]`. */
final class ProductController
{
    /** @param array{slug: string} $params */
    public function show(array $params): void
    {
        $ctx = AppContext::current();

        $product = null;
        $error = null;
        try {
            $result = $ctx->mudbase->listDocuments($ctx->productsCollectionId, ['slug' => $params['slug']], '-createdAt', 1, 1);
            $product = $result['data'][0] ?? null;
        } catch (MudbaseApiError $e) {
            $error = $e->getMessage();
        }

        if ($product === null) {
            View::render('product_detail', ['product' => null, 'error' => $error], $error !== null ? 502 : 404);
            return;
        }

        $gallery = Json::parseField($product['galleryJson'] ?? null, []);
        $images = array_values(array_filter([$product['imageUrl'] ?? null, ...$gallery], fn ($url) => is_string($url) && $url !== ''));

        View::render('product_detail', [
            'product' => $product,
            'images' => $images,
            'error' => null,
        ]);
    }
}
