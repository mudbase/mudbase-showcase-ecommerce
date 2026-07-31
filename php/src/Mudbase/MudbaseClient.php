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
use Mudbase\Sdk\Model\RegisterWithRoleRequest;

/**
 * Thin wrapper around the real, generated Mudbase PHP SDK (composer package `mudbase/sdk`,
 * namespace `Mudbase\Sdk`). There is no unified higher-level client in the real SDK — every method
 * here is a direct, documented SDK call (see php/docs/Api/AuthenticationApi.md,
 * MultiRoleFeatureApi.md, DataApi.md in the sibling mudbase-sdk clone) with just enough glue to
 * make it usable from plain PHP controllers: auth flows that return a usable session in one call,
 * and collection CRUD that returns plain arrays instead of the SDK's generated model objects.
 *
 * Two real SDK gaps this class works around (documented in README "Known limitations", not silent
 * workarounds):
 *
 * 1. `MultiRoleFeatureApi::registerWithRole()` — the endpoint that signs a user up with a specific
 *    application role (`POST /api/auth/local/signup/{role}`) — is generated with a `void` return
 *    type. Reading the generated source (registerWithRoleWithHttpInfo in
 *    lib/Api/MultiRoleFeatureApi.php) confirms this isn't a docs typo: the method really does
 *    discard the response body. So registration here is two real SDK calls chained: register the
 *    account (discarding the body), then `loginLocalUser()` immediately after with the same
 *    credentials to obtain a token.
 *
 * 2. `DataApi::listData()` deserializes into `DataListResponseDataInner`, a typed model that only
 *    declares `_id`, `created_at`, `updated_at` (see docs/Model/DataListResponseDataInner.md) — the
 *    generator had no way to type a project's user-defined collection fields, and unlike the
 *    single-document endpoints (whose `data` property is typed as a passthrough `object`), it did
 *    not fall back to a generic map for the list variant. Every actual field (name, priceCents,
 *    orderStatus, itemsJson, ...) is silently dropped by the typed method. This class calls
 *    `DataApi::listDataRequest()` — a public method on the generated class that builds the same
 *    signed PSR-7 request (path templating, query encoding, Bearer header from Configuration) —
 *    and sends it through the SDK's own Guzzle client, then decodes the JSON body itself instead
 *    of routing it through the lossy typed deserializer.
 */
final class MudbaseClient
{
    private readonly Configuration $config;
    private readonly GuzzleClient $httpClient;
    private readonly AuthenticationApi $auth;
    private readonly MultiRoleFeatureApi $multiRole;
    private readonly DataApi $data;

    public function __construct(
        private readonly string $baseUrl,
        private readonly string $projectId,
        private readonly ?string $accessToken = null,
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

    /** Returns a new client bound to the same project/host but a different bearer token. */
    public function withToken(string $token): self
    {
        return new self($this->baseUrl, $this->projectId, $token);
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

        try {
            $response = $this->auth->createAnonymousSession($request);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Anonymous session did not return a token', 500);
        }

        $authed = $this->withToken($token);
        return [
            'token' => $token,
            'refreshToken' => $response->getRefreshToken(),
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /**
     * Signs a brand-new account up with a specific application role
     * (`POST /api/auth/local/signup/{role}`, role = "customer" or "seller" — see
     * MultiRoleFeatureApi::registerWithRole). Chained with an immediate login because the signup
     * endpoint's generated method discards its response body (see class docblock, gap #1).
     *
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function registerWithRole(string $role, string $email, string $password, string $firstName, string $lastName): array
    {
        $request = new RegisterWithRoleRequest([
            'email' => $email,
            'password' => $password,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'project_id' => $this->projectId,
        ]);

        try {
            $this->multiRole->registerWithRole($role, $request);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        return $this->login($email, $password);
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

        try {
            $response = $this->auth->loginLocalUser($request);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Login did not return a token', 500);
        }

        $authed = $this->withToken($token);
        return [
            'token' => $token,
            'refreshToken' => $response->getRefreshToken(),
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
        try {
            $response = $this->auth->getLocalSession($this->projectId);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

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

        try {
            // See class docblock gap #2 — listDataRequest() builds the same signed request the
            // typed listData() would send; we just decode the body ourselves instead of letting
            // it flow through the lossy DataListResponseDataInner model.
            $request = $this->data->listDataRequest($this->projectId, $collectionId, $page, $limit, $sort, $filterJson);
            $response = $this->httpClient->send($request, ['http_errors' => false]);
        } catch (GuzzleException $e) {
            throw new MudbaseApiError($e->getMessage(), 502);
        }

        $status = $response->getStatusCode();
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
        try {
            $response = $this->data->getData($this->projectId, $collectionId, $documentId);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function createDocument(string $collectionId, array $fields): array
    {
        try {
            $response = $this->data->createData($this->projectId, $collectionId, $fields);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function updateDocument(string $collectionId, string $documentId, array $fields): array
    {
        try {
            $response = $this->data->updateData($this->projectId, $collectionId, $documentId, $fields);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    public function deleteDocument(string $collectionId, string $documentId): void
    {
        try {
            $this->data->deleteData($this->projectId, $collectionId, $documentId);
        } catch (ApiException $e) {
            throw MudbaseApiError::fromApiException($e);
        }
    }
}
