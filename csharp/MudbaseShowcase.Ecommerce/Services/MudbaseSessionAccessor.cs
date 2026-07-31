using System.Text.Json;
using Microsoft.AspNetCore.Http;
using MudbaseShowcase.Ecommerce.Models;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Reads/writes the current browser session's Mudbase JWT and cached user info in ASP.NET Core's
/// server-side session state — the JWT never reaches client JS. Registered as a singleton: it
/// only closes over IHttpContextAccessor (itself safe as a singleton, since it resolves the
/// ambient HttpContext per call via AsyncLocal), so every read/write here is already scoped to
/// whichever request is currently in flight. This lets <see cref="SessionBearerTokenProvider"/>
/// (also a singleton, per the SDK's DI wiring) depend on it directly without a scoped-from-
/// singleton DI violation.
/// </summary>
public sealed class MudbaseSessionAccessor
{
    private const string TokenKey = "mb_token";
    private const string UserKey = "mb_user";
    private const string GuestCartKey = "mb_guest_cart";

    private readonly IHttpContextAccessor _httpContextAccessor;

    public MudbaseSessionAccessor(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    private ISession Session =>
        _httpContextAccessor.HttpContext?.Session
        ?? throw new InvalidOperationException("MudbaseSessionAccessor was used outside an active HTTP request.");

    public bool HasToken => !string.IsNullOrEmpty(Session.GetString(TokenKey));

    public string? GetToken() => Session.GetString(TokenKey);

    public void SetToken(string token) => Session.SetString(TokenKey, token);

    public void ClearToken() => Session.Remove(TokenKey);

    public MudbaseSessionUser? CurrentUser
    {
        get
        {
            string? raw = Session.GetString(UserKey);
            if (raw is null) return null;
            try
            {
                return JsonSerializer.Deserialize<MudbaseSessionUser>(raw, MudbaseJson.Options);
            }
            catch (JsonException)
            {
                return null;
            }
        }
    }

    public void SetUser(MudbaseSessionUser user) => Session.SetString(UserKey, JsonSerializer.Serialize(user, MudbaseJson.Options));

    public void ClearUser() => Session.Remove(UserKey);

    public string? GetGuestCartJson() => Session.GetString(GuestCartKey);

    public void SetGuestCartJson(string json) => Session.SetString(GuestCartKey, json);

    public void ClearGuestCart() => Session.Remove(GuestCartKey);
}
