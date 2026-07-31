using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Mudbase.Sdk.Api;
using Mudbase.Sdk.Model;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Everything auth-related: bootstrapping a guest anonymous session so browsing works without
/// signing in, customer self-registration, login, session refresh, and logout.
///
/// One endpoint deliberately bypasses the generated SDK: registration goes through
/// POST /api/auth/local/signup/:role (Mudbase's Multi-Role feature), which the OpenAPI spec this
/// SDK was generated from models as `MultiRoleFeatureApi.RegisterWithRoleAsync(string role,
/// RegisterWithRoleRequest)` returning `void` with a request model of only
/// email/password/firstName/lastName/projectId. Two real gaps against the live endpoint's actual
/// behavior:
///   1. The live validator requires `agreedToTerms: true` in the body or rejects the signup — the
///      generated request model has no such property and no JsonExtensionData to smuggle one in.
///   2. The live endpoint returns a body (message/token/refreshToken/expiresIn/user) that the
///      spec's missing response schema left the generator no choice but to type as `void`.
/// Rather than fabricate a nonexistent SDK method or silently drop agreedToTerms (which would make
/// every real registration fail), this calls the endpoint directly via a plain HttpClient bound to
/// the same Mudbase base URL, and parses the response body itself. See README "Known limitations".
/// </summary>
public sealed class MudbaseAuthService
{
    private readonly IAuthenticationApi _authApi;
    private readonly HttpClient _rawHttpClient;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;
    private readonly ILogger<MudbaseAuthService> _logger;

    public MudbaseAuthService(
        IAuthenticationApi authApi,
        IHttpClientFactory httpClientFactory,
        MudbaseSessionAccessor session,
        IOptions<MudbaseOptions> options,
        ILogger<MudbaseAuthService> logger)
    {
        _authApi = authApi;
        _rawHttpClient = httpClientFactory.CreateClient(HttpClientNames.MudbaseRaw);
        _session = session;
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>
    /// Guest browsing with no signup: an anonymous session lets the catalog's "authenticated"-role
    /// read permission resolve without forcing signup. Carts stay in the browser session (see
    /// CartService) until checkout, where a real "customer" account is required for order/cart
    /// write permissions. Called once per browser session by EnsureMudbaseSessionMiddleware.
    /// </summary>
    public async Task EnsureAnonymousSessionAsync(CancellationToken cancellationToken)
    {
        if (_session.HasToken)
        {
            return;
        }

        try
        {
            ICreateAnonymousSessionApiResponse response =
                await _authApi.CreateAnonymousSessionAsync(new CreateAnonymousSessionRequest(_options.ProjectId), cancellationToken);

            if (response.TryOk(out CreateAnonymousSession200Response? body) && body?.Token is { Length: > 0 } token)
            {
                _session.SetToken(token);
                await RefreshSessionAsync(cancellationToken);
            }
            else
            {
                _logger.LogWarning("Anonymous Mudbase session bootstrap failed with status {StatusCode}", response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Anonymous Mudbase session bootstrap could not reach Mudbase");
        }
    }

    public async Task<AuthOutcome> RegisterCustomerAsync(
        string email, string password, string firstName, string lastName, bool agreedToTerms, CancellationToken cancellationToken)
    {
        var payload = new Dictionary<string, object?>
        {
            ["email"] = email,
            ["password"] = password,
            ["firstName"] = firstName,
            ["lastName"] = lastName,
            ["projectId"] = _options.ProjectId,
            ["agreedToTerms"] = agreedToTerms,
        };

        using HttpResponseMessage response = await _rawHttpClient.PostAsJsonAsync(
            "/api/auth/local/signup/customer", payload, MudbaseJson.Options, cancellationToken);

        string raw = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            return AuthOutcome.Failure(ExtractErrorMessage(raw) ?? $"Registration failed ({(int)response.StatusCode}).");
        }

        SignupWithRoleResponsePayload? parsed = SafeDeserialize<SignupWithRoleResponsePayload>(raw);

        if (parsed?.RequireVerification == true || parsed?.Token is null)
        {
            return AuthOutcome.NeedsEmailVerification(
                parsed?.Message ?? "Account created — check your email to verify it, then sign in.");
        }

        _session.SetToken(parsed.Token);
        await RefreshSessionAsync(cancellationToken);
        return AuthOutcome.Success();
    }

    public async Task<AuthOutcome> LoginAsync(string email, string password, CancellationToken cancellationToken)
    {
        LoginLocalUserRequest request = new(email, password, _options.ProjectId);
        ILoginLocalUserApiResponse response = await _authApi.LoginLocalUserAsync(request, cancellationToken);

        if (!response.TryOk(out LoginLocalUser200Response? body) || body?.Token is not { Length: > 0 } token)
        {
            return AuthOutcome.Failure(MudbaseApiException.From(response).Message);
        }

        _session.SetToken(token);
        await RefreshSessionAsync(cancellationToken);
        return AuthOutcome.Success();
    }

    /// <summary>
    /// Fetches the full, authoritative session user (including customRole, which the login/signup
    /// responses' typed models don't expose) and caches it in session state. Call after every
    /// token change (login, register, anonymous bootstrap) — mirrors refreshSession() in
    /// web/src/lib/mudbase-provider.tsx.
    /// </summary>
    public async Task RefreshSessionAsync(CancellationToken cancellationToken)
    {
        if (!_session.HasToken)
        {
            _session.ClearUser();
            return;
        }

        IGetLocalSessionApiResponse response = await _authApi.GetLocalSessionAsync(_options.ProjectId, cancellationToken);

        if (!response.TryOk(out GetLocalSession200Response? body) || body?.User is not JsonElement userElement)
        {
            _session.ClearToken();
            _session.ClearUser();
            return;
        }

        MudbaseSessionUser? user = JsonSerializer.Deserialize<MudbaseSessionUser>(userElement.GetRawText(), MudbaseJson.Options);
        _session.SetUser(user ?? new MudbaseSessionUser());
    }

    public async Task LogoutAsync(CancellationToken cancellationToken)
    {
        if (_session.HasToken)
        {
            try
            {
                await _authApi.LogoutLocalUserAsync(cancellationToken);
            }
            catch (HttpRequestException ex)
            {
                // Best-effort: the browser's session is cleared regardless so the user is signed
                // out locally even if Mudbase couldn't be reached to revoke server-side.
                _logger.LogWarning(ex, "Mudbase logout call failed; clearing local session anyway");
            }
        }

        _session.ClearToken();
        _session.ClearUser();
        _session.ClearGuestCart();
    }

    private static string? ExtractErrorMessage(string raw)
    {
        PayLinkErrorPayload? payload = SafeDeserialize<PayLinkErrorPayload>(raw);
        return payload?.Error;
    }

    private static T? SafeDeserialize<T>(string raw) where T : class
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        try
        {
            return JsonSerializer.Deserialize<T>(raw, MudbaseJson.Options);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
