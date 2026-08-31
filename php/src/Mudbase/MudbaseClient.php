<?php

declare(strict_types=1);

namespace App\Mudbase;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;
use Mudbase\Sdk\Api\AuthenticationApi;
use Mudbase\Sdk\Api\DataApi;
use Mudbase\Sdk\Api\MultiRoleFeatureApi;
use Mudbase\Sdk\ApiException;
use Mudbase\Sdk\Configuration;
use Mudbase\Sdk\Model\CreateAnonymousSessionRequest;
use Mudbase\Sdk\Model\LoginLocalUserRequest;
use Mudbase\Sdk\Model\RefreshTokenRequest;
use Mudbase\Sdk\Model\RegisterWithRoleRequest;

/**
 * Thin wrapper around the real, generated Mudbase PHP SDK (composer package `mudbase/sdk`,
 * namespace `Mudbase\Sdk`). There is no unified higher-level client in the real SDK — every method
 * here is a direct, documented SDK call (see php/docs/Api/AuthenticationApi.md,
 * MultiRoleFeatureApi.md, DataApi.md in the sibling mudbase-sdk clone) with just enough glue to
 * make it usable from plain PHP controllers: auth flows that return a usable session in one call,
 * and collection CRUD that returns plain arrays instead of the SDK's generated model objects.
 *
 * One real SDK gap this class still works around (documented in README "Known limitations", not a
 * silent workaround):
 *
 * `DataApi::listData()` deserializes into `DataListResponseDataInner`, a typed model that only
 * declares `_id`, `created_at`, `updated_at` (see docs/Model/DataListResponseDataInner.md) — the
 * generator had no way to type a project's user-defined collection fields, and unlike the
 * single-document endpoints (whose `data` property is typed as a passthrough `object`), it did
 * not fall back to a generic map for the list variant. Every actual field (name, priceCents,
 * orderStatus, itemsJson, ...) is silently dropped by the typed method. This class calls
 * `DataApi::listDataRequest()` — a public method on the generated class that builds the same
 * signed PSR-7 request (path templating, query encoding, Bearer header from Configuration) —
 * and sends it through the SDK's own Guzzle client, then decodes the JSON body itself instead
 * of routing it through the lossy typed deserializer.
 *
 * A previously-documented gap is now fixed upstream and no longer worked around here:
 * `MultiRoleFeatureApi::registerWithRole()` used to be generated with a `void` return type
 * (confirmed by reading the generated source at the time), so registration needed two chained SDK
 * calls — register (discarding the body), then `loginLocalUser()` immediately after with the same
 * credentials just to obtain a token. The regenerated SDK now types this endpoint's 201 response
 * as `RegisterWithRole201Response`, which carries `token`/`refreshToken` directly — see
 * `registerWithRole()` below, now a single SDK call plus the same `fetchSessionUser()` call every
 * other auth method makes (see that method's docblock for why).
 *
 * Access-token refresh: every method that hits the SDK funnels through `callApi()` (ApiException-
 * based calls) or the inline retry in `listDocuments()` (its own raw-Guzhttp path, see gap above).
 * Both attempt exactly one silent refresh-and-retry on a 401 using the refresh token this instance
 * was constructed with, via `POST /api/auth/refresh` (`AuthenticationApi::refreshToken()`). A
 * successful refresh calls the optional `$onTokenRefreshed` callback so the caller (bootstrap.php)
 * can persist the new pair into `$_SESSION` — this class has no `$_SESSION` dependency of its own,
 * keeping it usable outside a web request (e.g. from a CLI script). If the refresh itself fails
 * (refresh token expired/revoked too), the original 401 is rethrown as `MudbaseApiError` and the
 * front controller's existing "clear session, re-bootstrap as guest" fallback (public/index.php)
 * takes over — that path is now the genuinely-unrecoverable case, not the common one.
 */
final class MudbaseClient
{
    private readonly Configuration $config;
    private readonly GuzzleClient $httpClient;
    private readonly AuthenticationApi $auth;
    private readonly MultiRoleFeatureApi $multiRole;
    private readonly DataApi $data;

    /**
     * @param (callable(string $token, ?string $refreshToken): void)|null $onTokenRefreshed
     *        Invoked once, synchronously, immediately after a successful silent token refresh —
     *        the caller's chance to persist the new pair (e.g. into `$_SESSION`) before the
     *        retried call goes out with it.
     */
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $projectId,
        private ?string $accessToken = null,
        private ?string $refreshTokenValue = null,
        private readonly mixed $onTokenRefreshed = null,
    ) {
        $this->config = Configuration::getDefaultConfiguration()->setHost($this->baseUrl);
        if ($this->accessToken !== null) {
            $this->config->setAccessToken($this->accessToken);
        }
        $this->httpClient = new GuzzleClient();
        $this->auth = new AuthenticationApi($this->httpClient, $this->config);
        $this->multiRole = new MultiRoleFeatureApi($this->httpClient, $this->config);
        $this->data = new DataApi($this->httpClient, $this->config);
    }

    /**
     * Returns a new client bound to the same project/host but a different bearer token (and,
     * usually, its paired refresh token). Carries the refresh-callback forward so a client handed
     * out after login/register can still self-heal on a later 401 the same way the original could.
     */
    public function withToken(string $token, ?string $refreshToken = null): self
    {
        return new self($this->baseUrl, $this->projectId, $token, $refreshToken, $this->onTokenRefreshed);
    }

    // ─── Auth ────────────────────────────────────────────────────────────────

    /**
     * Establishes a guest session (`POST /api/auth/anonymous`). Product reads require the
     * `authenticated` role — Mudbase's anonymous sessions satisfy that (systemRole "viewer",
     * customRole null) without forcing a real signup, exactly like the reference Next.js app's
     * auto-anonymous-login-on-first-load behavior in src/lib/mudbase-provider.tsx.
     *
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function establishAnonymousSession(): array
    {
        $request = new CreateAnonymousSessionRequest(['project_id' => $this->projectId]);

        $response = $this->callApi(fn () => $this->auth->createAnonymousSession($request));

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Anonymous session did not return a token', 500);
        }

        $refreshToken = $response->getRefreshToken();
        $authed = $this->withToken($token, $refreshToken);
        return [
            'token' => $token,
            'refreshToken' => $refreshToken,
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /**
     * Signs a brand-new account up with a specific application role
     * (`POST /api/auth/local/signup/{role}`, role = "customer" or "seller" — see
     * MultiRoleFeatureApi::registerWithRole). `agreedToTerms` must be `true` — the server rejects
     * the request otherwise (see `RegisterWithRoleRequest::setAgreedToTerms()`'s docblock in the
     * generated SDK); this app's registration form already hard-requires the checkbox before
     * calling here (see AuthController::register()), so it is never silently defaulted.
     *
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function registerWithRole(
        string $role,
        string $email,
        string $password,
        string $firstName,
        string $lastName,
        bool $agreedToTerms,
    ): array {
        $request = new RegisterWithRoleRequest([
            'email' => $email,
            'password' => $password,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'project_id' => $this->projectId,
            'agreed_to_terms' => $agreedToTerms,
        ]);

        $response = $this->callApi(fn () => $this->multiRole->registerWithRole($role, $request));

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Registration did not return a token', 500);
        }

        $refreshToken = $response->getRefreshToken();
        $authed = $this->withToken($token, $refreshToken);
        return [
            'token' => $token,
            'refreshToken' => $refreshToken,
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /**
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function login(string $email, string $password): array
    {
        $request = new LoginLocalUserRequest([
            'email' => $email,
            'password' => $password,
            'project_id' => $this->projectId,
        ]);

        $response = $this->callApi(fn () => $this->auth->loginLocalUser($request));

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Login did not return a token', 500);
        }

        $refreshToken = $response->getRefreshToken();
        $authed = $this->withToken($token, $refreshToken);
        return [
            'token' => $token,
            'refreshToken' => $refreshToken,
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /** Best-effort — the caller clears its local session regardless of whether this succeeds. */
    public function logout(): void
    {
        try {
            $this->auth->logoutLocalUser();
        } catch (ApiException) {
            // Session may already be expired/invalid server-side; nothing left to revoke.
        }
    }

    /**
     * `GET /api/auth/local/session` — the authoritative source of the current user's full
     * application state (id, email, name, `customRole`, `isAnonymous`, ...). Deliberately used
     * instead of trusting the narrower typed `user` objects returned by login/register/anonymous
     * (see class docblock): `GetLocalSession200Response.user` is typed as a passthrough `object`
     * in the OpenAPI spec, so every field the server actually returns survives deserialization,
     * whereas e.g. `LoginLocalUser200ResponseUser` only declares id/email/firstName/lastName/role/
     * emailVerified/twoFactorEnabled — no `customRole`, which every role gate in this app needs.
     *
     * @return array<string, mixed>
     */
    public function fetchSessionUser(): array
    {
        $response = $this->callApi(fn () => $this->auth->getLocalSession($this->projectId));

        $user = $response->getUser();
        return is_array($user) ? $user : [];
    }

    // ─── Collections ─────────────────────────────────────────────────────────

    /**
     * @param array<string, mixed>|null $filter
     * @return array{data: list<array<string, mixed>>, pagination: array{page: int, limit: int, total: int, totalPages: int}}
     */
    public function listDocuments(
        string $collectionId,
        ?array $filter = null,
        string $sort = '-createdAt',
        int $page = 1,
        int $limit = 20,
    ): array {
        $filterJson = $filter !== null && $filter !== [] ? json_encode($filter) : null;

        $refreshed = false;
        while (true) {
            try {
                // See class docblock gap — listDataRequest() builds the same signed request the
                // typed listData() would send; we just decode the body ourselves instead of
                // letting it flow through the lossy DataListResponseDataInner model. Rebuilding
                // the request (rather than reusing one PSR-7 instance) on a retry matters: it
                // reads the Bearer header from $this->config fresh each call, so it picks up the
                // token callApi()'s refresh path just wrote into $this->config.
                $request = $this->data->listDataRequest($this->projectId, $collectionId, $page, $limit, $sort, $filterJson);
                $response = $this->httpClient->send($request, ['http_errors' => false]);
            } catch (GuzzleException $e) {
                throw new MudbaseApiError($e->getMessage(), 502);
            }

            $status = $response->getStatusCode();
            if ($status === 401 && !$refreshed && $this->refreshAccessToken()) {
                $refreshed = true;
                continue;
            }
            break;
        }

        $decoded = json_decode((string) $response->getBody(), true);

        if ($status >= 400) {
            throw MudbaseApiError::fromResponse($status, $decoded);
        }

        $data = is_array($decoded) && is_array($decoded['data'] ?? null) ? $decoded['data'] : [];
        $pagination = is_array($decoded) && is_array($decoded['pagination'] ?? null) ? $decoded['pagination'] : [];

        return [
            'data' => array_values($data),
            'pagination' => [
                'page' => (int) ($pagination['page'] ?? $page),
                'limit' => (int) ($pagination['limit'] ?? $limit),
                'total' => (int) ($pagination['total'] ?? count($data)),
                'totalPages' => (int) ($pagination['totalPages'] ?? 1),
            ],
        ];
    }

    /** @return array<string, mixed> */
    public function getDocument(string $collectionId, string $documentId): array
    {
        $response = $this->callApi(fn () => $this->data->getData($this->projectId, $collectionId, $documentId));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function createDocument(string $collectionId, array $fields): array
    {
        $response = $this->callApi(fn () => $this->data->createData($this->projectId, $collectionId, $fields));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function updateDocument(string $collectionId, string $documentId, array $fields): array
    {
        $response = $this->callApi(fn () => $this->data->updateData($this->projectId, $collectionId, $documentId, $fields));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    public function deleteDocument(string $collectionId, string $documentId): void
    {
        $this->callApi(fn () => $this->data->deleteData($this->projectId, $collectionId, $documentId));
    }

    // ─── Token refresh ───────────────────────────────────────────────────────

    /**
     * Runs one SDK call (anything that throws the generated `ApiException` on a non-2xx
     * response). On a 401, attempts exactly one silent refresh via the stored refresh token and,
     * if that succeeds, retries the same call once more with the new token already baked into
     * `$this->config` (every generated Api class shares that same Configuration instance, so the
     * retried call picks it up automatically). Any other status, or a failed/absent refresh,
     * surfaces as the usual `MudbaseApiError`.
     *
     * @template T
     * @param callable(): T $sdkCall
     * @return T
     */
    private function callApi(callable $sdkCall): mixed
    {
        try {
            return $sdkCall();
        } catch (ApiException $e) {
            if ($e->getCode() === 401 && $this->refreshAccessToken()) {
                try {
                    return $sdkCall();
                } catch (ApiException $retryException) {
                    throw MudbaseApiError::fromApiException($retryException);
                }
            }

            throw MudbaseApiError::fromApiException($e);
        }
    }

    /**
     * `POST /api/auth/refresh` — exchanges the stored refresh token for a new access/refresh
     * pair. Returns false (never throws) when there is no refresh token to use or the exchange
     * itself fails, so callers can fall back to surfacing the original 401 instead of masking it
     * with a confusing refresh-endpoint error. On success, mutates this instance's Configuration
     * in place (so already-constructed Api clients pick up the new Bearer token immediately) and
     * invokes `$onTokenRefreshed` so the caller can persist the new pair.
     */
    private function refreshAccessToken(): bool
    {
        if ($this->refreshTokenValue === null || $this->refreshTokenValue === '') {
            return false;
        }

        try {
            $response = $this->auth->refreshToken(new RefreshTokenRequest([
                'refresh_token' => $this->refreshTokenValue,
            ]));
        } catch (ApiException) {
            // Refresh token itself expired/revoked/invalid — nothing left to recover with.
            return false;
        }

        $newToken = $response->getToken();
        if (!is_string($newToken) || $newToken === '') {
            return false;
        }

        $newRefreshToken = $response->getRefreshToken();
        $this->accessToken = $newToken;
        $this->refreshTokenValue = is_string($newRefreshToken) && $newRefreshToken !== ''
            ? $newRefreshToken
            : $this->refreshTokenValue;
        $this->config->setAccessToken($newToken);

        if ($this->onTokenRefreshed !== null) {
            ($this->onTokenRefreshed)($this->accessToken, $this->refreshTokenValue);
        }

        return true;
    }
}
