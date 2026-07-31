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
/// Every call here goes through the generated SDK. Registration used to bypass it — the SDK's
/// `MultiRoleFeatureApi.RegisterWithRoleAsync` request model was missing `agreedToTerms` (which the
/// live validator requires) and its response was typed `void` (the OpenAPI spec this SDK was
/// generated from had left the response schema unspecified) — but a regenerated SDK now models
/// both correctly (`RegisterWithRoleRequest.AgreedToTerms`, a typed `RegisterWithRole201Response`
/// with token/refreshToken/user/role), so <see cref="RegisterCustomerAsync"/> below calls the
/// generated method directly like everything else in this class.
/// </summary>
public sealed class MudbaseAuthService
{
    private readonly IAuthenticationApi _authApi;
    private readonly IMultiRoleFeatureApi _multiRoleApi;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;
    private readonly ILogger<MudbaseAuthService> _logger;

    public MudbaseAuthService(
        IAuthenticationApi authApi,
        IMultiRoleFeatureApi multiRoleApi,
        MudbaseSessionAccessor session,
        IOptions<MudbaseOptions> options,
        ILogger<MudbaseAuthService> logger)
    {
        _authApi = authApi;
        _multiRoleApi = multiRoleApi;
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
                _session.SetTokens(token, body.RefreshToken);
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

    /// <summary>
    /// Self-signup is always the "customer" Multi-Role — see README "Provisioning" for why seller
    /// accounts are provisioned out-of-band instead. Calls the generated SDK's
    /// MultiRoleFeatureApi.RegisterWithRoleAsync directly (see this class's doc comment for why
    /// that used to require a raw-HttpClient workaround and no longer does).
    /// </summary>
    public async Task<AuthOutcome> RegisterCustomerAsync(
        string email, string password, string firstName, string lastName, bool agreedToTerms, CancellationToken cancellationToken)
    {
        RegisterWithRoleRequest request = new(email, password, firstName, lastName, _options.ProjectId, agreedToTerms);
        IRegisterWithRoleApiResponse response = await _multiRoleApi.RegisterWithRoleAsync("customer", request, cancellationToken);

        if (!response.TryCreated(out RegisterWithRole201Response? body) || body is null)
        {
            return AuthOutcome.Failure(MudbaseApiException.From(response).Message);
        }

        if (body.RequireVerification == true || body.Token is not { Length: > 0 } token)
        {
            return AuthOutcome.NeedsEmailVerification(
                body.Message ?? "Account created — check your email to verify it, then sign in.");
        }

        _session.SetTokens(token, body.RefreshToken);
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

        _session.SetTokens(token, body.RefreshToken);
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
}
