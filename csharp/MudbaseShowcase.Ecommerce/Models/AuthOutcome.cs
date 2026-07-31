namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>Result of a login/register attempt against Mudbase, for display in a Razor Page without throwing on expected failures.</summary>
public sealed class AuthOutcome
{
    public bool Succeeded { get; private init; }
    public string? ErrorMessage { get; private init; }
    public bool RequiresEmailVerification { get; private init; }

    public static AuthOutcome Success() => new() { Succeeded = true };

    public static AuthOutcome Failure(string message) => new() { Succeeded = false, ErrorMessage = message };

    public static AuthOutcome NeedsEmailVerification(string message) =>
        new() { Succeeded = false, ErrorMessage = message, RequiresEmailVerification = true };
}

/// <summary>
/// Raw shape of the /api/auth/local/signup/:role response. The generated SDK's
/// MultiRoleFeatureApi.RegisterWithRoleAsync models this endpoint's response as untyped (its
/// OpenAPI spec declares no response schema) — see README "Known limitations" — so
/// MudbaseAuthService parses this itself from the raw response body.
/// </summary>
public sealed class SignupWithRoleResponsePayload
{
    public string? Message { get; set; }
    public string? Token { get; set; }
    public string? RefreshToken { get; set; }
    public int? ExpiresIn { get; set; }
    public bool? RequireVerification { get; set; }
}
