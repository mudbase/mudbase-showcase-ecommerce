<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\View;

/**
 * Login/register/logout — mirrors the reference app's `/login`, `/register`, and `useAuth()`.
 * Role is never taken from the form: self-signup is always the `customer` role (see
 * RegisterForm.tsx — "role hidden, always customer").
 */
final class AuthController
{
    /** @param array<string, string> $params */
    public function loginForm(array $params): void
    {
        $ctx = AppContext::current();
        if ($ctx->isSignedIn()) {
            Response::redirect($ctx->isSeller() ? '/seller' : '/');
        }
        View::render('login', ['redirectTo' => (string) ($_GET['redirect'] ?? '/')]);
    }

    /** @param array<string, string> $params */
    public function login(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf('/login');

        $email = trim((string) ($_POST['email'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        $redirectTo = (string) ($_POST['redirectTo'] ?? '/');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $password === '') {
            Flash::set('error', 'Enter a valid email address and password.');
            Response::redirect('/login');
        }

        try {
            $session = $ctx->mudbase->login($email, $password);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->getMessage());
            Response::redirect('/login');
        }

        $this->establishSession($session);

        $signedInCtx = AppContext::current();
        if ($signedInCtx->isCustomer()) {
            $signedInCtx->cart->migrateGuestCartToServer($session['user']);
        }

        Response::redirect($signedInCtx->isSeller() ? '/seller' : $redirectTo);
    }

    /** @param array<string, string> $params */
    public function registerForm(array $params): void
    {
        $ctx = AppContext::current();
        if ($ctx->isSignedIn()) {
            Response::redirect('/');
        }
        View::render('register', ['redirectTo' => (string) ($_GET['redirect'] ?? '/')]);
    }

    /** @param array<string, string> $params */
    public function register(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf('/register');

        $firstName = trim((string) ($_POST['firstName'] ?? ''));
        $lastName = trim((string) ($_POST['lastName'] ?? ''));
        $email = trim((string) ($_POST['email'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        $agreedToTerms = ($_POST['agreedToTerms'] ?? null) === 'on';
        $redirectTo = (string) ($_POST['redirectTo'] ?? '/');

        $errors = [];
        if ($firstName === '') {
            $errors[] = 'First name is required.';
        }
        if ($lastName === '') {
            $errors[] = 'Last name is required.';
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $errors[] = 'Enter a valid email address.';
        }
        if (strlen($password) < 8) {
            $errors[] = 'Password must be at least 8 characters.';
        }
        if (!$agreedToTerms) {
            $errors[] = 'You must agree to the Terms of Service and Privacy Policy.';
        }

        if ($errors !== []) {
            Flash::set('error', implode(' ', $errors));
            Response::redirect('/register');
        }

        try {
            $session = $ctx->mudbase->registerWithRole('customer', $email, $password, $firstName, $lastName);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->getMessage());
            Response::redirect('/register');
        }

        $this->establishSession($session);
        AppContext::current()->cart->migrateGuestCartToServer($session['user']);

        Response::redirect($redirectTo);
    }

    /** @param array<string, string> $params */
    public function logout(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf('/');

        $ctx->mudbase->logout();
        unset($_SESSION['mudbase_token'], $_SESSION['mudbase_refresh_token'], $_SESSION['mudbase_user']);
        session_regenerate_id(true);

        Response::redirect('/');
    }

    /** @param array{token: string, refreshToken: ?string, user: array<string, mixed>} $session */
    private function establishSession(array $session): void
    {
        // Regenerate the session id on every privilege change (anonymous guest -> real account,
        // or one real account -> another) so a session identifier issued before authentication
        // can never be reused to ride along with the authenticated one.
        session_regenerate_id(true);

        $_SESSION['mudbase_token'] = $session['token'];
        $_SESSION['mudbase_refresh_token'] = $session['refreshToken'];
        $_SESSION['mudbase_user'] = $session['user'];

        // Rebuild the request-scoped context so the redirect target's isCustomer()/isSeller()
        // checks below reflect the account we just signed into, not the guest we booted this
        // request as.
        $ctx = AppContext::current();
        AppContext::set(new AppContext(
            mudbase: $ctx->mudbase->withToken($session['token']),
            user: $session['user'],
            cart: $ctx->cart,
            productsCollectionId: $ctx->productsCollectionId,
            ordersCollectionId: $ctx->ordersCollectionId,
            cartsCollectionId: $ctx->cartsCollectionId,
            mudbaseUrl: $ctx->mudbaseUrl,
            paymentLinkProxy: $ctx->paymentLinkProxy,
        ));
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
