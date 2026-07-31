<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\AuthController;
use App\Controllers\CartController;
use App\Controllers\CheckoutController;
use App\Controllers\HomeController;
use App\Controllers\OrderController;
use App\Controllers\ProductController;
use App\Controllers\SellerController;
use App\Mudbase\MudbaseApiError;
use App\Router;
use App\View;

$router = new Router();

$home = new HomeController();
$product = new ProductController();
$cart = new CartController();
$checkout = new CheckoutController();
$order = new OrderController();
$auth = new AuthController();
$seller = new SellerController();

$router->get('/', [$home, 'index']);
$router->get('/products/{slug}', [$product, 'show']);

$router->get('/cart', [$cart, 'index']);
$router->post('/cart/add', [$cart, 'add']);
$router->post('/cart/update', [$cart, 'update']);
$router->post('/cart/remove', [$cart, 'remove']);

$router->get('/checkout', [$checkout, 'index']);
$router->post('/checkout', [$checkout, 'submit']);
$router->get('/checkout/{token}', [$checkout, 'payment']);

$router->get('/orders', [$order, 'index']);
$router->get('/orders/{id}', [$order, 'show']);

$router->get('/login', [$auth, 'loginForm']);
$router->post('/login', [$auth, 'login']);
$router->get('/register', [$auth, 'registerForm']);
$router->post('/register', [$auth, 'register']);
$router->post('/logout', [$auth, 'logout']);

$router->get('/seller', [$seller, 'dashboard']);
$router->get('/seller/orders-fragment', [$seller, 'ordersFragment']);
$router->post('/seller/orders/{id}/advance', [$seller, 'advanceOrder']);
$router->get('/seller/products/new', [$seller, 'newProductForm']);
$router->post('/seller/products/new', [$seller, 'createProduct']);
$router->get('/seller/products/{id}/edit', [$seller, 'editProductForm']);
$router->post('/seller/products/{id}/edit', [$seller, 'updateProduct']);
$router->post('/seller/products/{id}/delete', [$seller, 'deleteProduct']);

try {
    $router->dispatch((string) $_SERVER['REQUEST_METHOD'], (string) $_SERVER['REQUEST_URI'], function (): void {
        View::render('errors/not_found', [], 404);
    });
} catch (MudbaseApiError $e) {
    if ($e->isUnauthorized()) {
        // Token expired/was revoked mid-session — clear it and re-bootstrap as a fresh guest on
        // the next load rather than showing the shopper a raw auth error.
        unset($_SESSION['mudbase_token'], $_SESSION['mudbase_refresh_token'], $_SESSION['mudbase_user']);
        header('Location: ' . $_SERVER['REQUEST_URI']);
        exit;
    }

    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
} catch (\Throwable $e) {
    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
}
