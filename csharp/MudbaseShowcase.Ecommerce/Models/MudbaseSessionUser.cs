using System.Text.Json.Serialization;

namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>
/// The authenticated user info this app cares about, parsed from Mudbase's session/user payloads
/// (which the generated SDK types loosely as `Object` — see
/// <see cref="MudbaseShowcase.Ecommerce.Services.MudbaseAuthService"/>). Mirrors
/// web/src/lib/mudbase.ts's UserObject.
/// </summary>
public sealed class MudbaseSessionUser
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("firstName")]
    public string FirstName { get; set; } = string.Empty;

    [JsonPropertyName("lastName")]
    public string LastName { get; set; } = string.Empty;

    [JsonPropertyName("role")]
    public string? Role { get; set; }

    /// <summary>Mudbase Multi-Role customRole: "customer" or "seller" for this app.</summary>
    [JsonPropertyName("customRole")]
    public string? CustomRole { get; set; }

    [JsonPropertyName("emailVerified")]
    public bool EmailVerified { get; set; }

    [JsonPropertyName("isAnonymous")]
    public bool? IsAnonymous { get; set; }

    public bool IsSeller => CustomRole == "seller";

    public bool IsCustomer => CustomRole == "customer";

    /// <summary>True for a real signed-in account (customer or seller), false for a guest anonymous session.</summary>
    public bool IsSignedIn => IsAnonymous != true;
}
