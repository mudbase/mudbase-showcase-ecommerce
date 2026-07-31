<?php

declare(strict_types=1);

use App\Config;
use App\Http\AppContext;
use App\Mudbase\MudbaseApiError;
use App\Mudbase\MudbaseClient;
use App\Support\Cart;
use App\Support\PaymentLinkProxy;

require dirname(__DIR__) . '/vendor/autoload.php';

$rootDir = dirname(__DIR__);
Config::load($rootDir);

session_name(Config::optional('SESSION_NAME', 'mudbase_showcase_php'));
session_start();

$mudbaseUrl = rtrim(Config::optional('MUDBASE_URL', 'https://cloud.mudbase.dev'), '/');
$projectId = Config::required('MUDBASE_PROJECT_ID');
$productsCollectionId = Config::required('MUDBASE_PRODUCTS_COLLECTION_ID');
$ordersCollectionId = Config::required('MUDBASE_ORDERS_COLLECTION_ID');
$cartsCollectionId = Config::required('MUDBASE_CARTS_COLLECTION_ID');
$payLinkProxyUrl = Config::required('PAY_LINK_PROXY_URL');

/**
 * On first visit (no token yet), establish an anonymous guest session so catalog reads — which
 * require the `authenticated` role — work without forcing a signup, mirroring the reference
 * Next.js app's auto-anonymous-login-on-mount behavior. Once a token exists, this app trusts the
 * user snapshot cached in $_SESSION at the time of that auth call rather than re-validating with
 * Mudbase on every single page load (a stateless SPA revalidates once per client mount; a
 * server-rendered app re-mounts on every request, so doing the same here would mean one Mudbase
 * round trip per page view). If a token has actually expired, the first API call that hits it
 * receives a 401, which the front controller (public/index.php) catches, clears the session, and
 * redirects back to the same URL to re-bootstrap as a fresh guest — see "Known limitations" in
 * README for the tradeoff.
 *
 * Deliberately caught broadly here (not just MudbaseApiError): with no live Mudbase project/API
 * key configured, this call fails at the transport level (DNS/connection), and the app must still
 * boot and render the catalog shell rather than fatal-erroring on every request.
 */
if (!isset($_SESSION['mudbase_token'])) {
    try {
        $anonClient = new MudbaseClient($mudbaseUrl, $projectId);
        $session = $anonClient->establishAnonymousSession();
        $_SESSION['mudbase_token'] = $session['token'];
        $_SESSION['mudbase_refresh_token'] = $session['refreshToken'];
        $_SESSION['mudbase_user'] = $session['user'];
    } catch (\Throwable) {
        // No live Mudbase project reachable (e.g. local smoke-testing without credentials) — fall
        // through with no session. Pages that need collection data will surface their own
        // "couldn't load" state instead of a fatal error; that is the intended degraded mode.
        $_SESSION['mudbase_token'] = null;
        $_SESSION['mudbase_user'] = null;
    }
}

$token = $_SESSION['mudbase_token'] ?? null;
$mudbase = new MudbaseClient($mudbaseUrl, $projectId, is_string($token) ? $token : null);
$user = is_array($_SESSION['mudbase_user'] ?? null) ? $_SESSION['mudbase_user'] : null;
$cart = new Cart($mudbase, $cartsCollectionId);
$paymentLinkProxy = new PaymentLinkProxy($payLinkProxyUrl, $mudbaseUrl);

AppContext::set(new AppContext(
    mudbase: $mudbase,
    user: $user,
    cart: $cart,
    productsCollectionId: $productsCollectionId,
    ordersCollectionId: $ordersCollectionId,
    cartsCollectionId: $cartsCollectionId,
    mudbaseUrl: $mudbaseUrl,
    paymentLinkProxy: $paymentLinkProxy,
));
