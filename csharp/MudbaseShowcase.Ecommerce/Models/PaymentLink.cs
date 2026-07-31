using System.Text.Json.Serialization;

namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>
/// A Mudbase Payment Link object, as returned both by the pay-link creation proxy and by the
/// public GET /api/payment-links/:token status endpoint. Mirrors web/src/lib/mudbase-server.ts's
/// PaymentLink / PublicPaymentLink (this app never sees the private fields — token/amount/
/// currency/network/address/description/redirectUrl/status/expiresAt cover both call sites).
/// </summary>
public sealed class PaymentLink
{
    [JsonPropertyName("token")]
    public string Token { get; set; } = string.Empty;

    [JsonPropertyName("amount")]
    public string? Amount { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = string.Empty;

    [JsonPropertyName("network")]
    public string Network { get; set; } = string.Empty;

    [JsonPropertyName("address")]
    public string? Address { get; set; }

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("redirectUrl")]
    public string? RedirectUrl { get; set; }

    /// <summary>One of "pending" | "paid" | "expired" | "cancelled".</summary>
    [JsonPropertyName("status")]
    public string Status { get; set; } = "pending";

    [JsonPropertyName("expiresAt")]
    public DateTimeOffset? ExpiresAt { get; set; }
}

/// <summary>Envelope for POST /api/checkout/pay-link's success response: {"link": {...}}.</summary>
public sealed class PayLinkCreateSuccessPayload
{
    [JsonPropertyName("link")]
    public PaymentLink? Link { get; set; }
}

/// <summary>Envelope for POST /api/checkout/pay-link's error response: {"error": "...", "reason": "..."}.</summary>
public sealed class PayLinkErrorPayload
{
    [JsonPropertyName("error")]
    public string? Error { get; set; }

    /// <summary>"kyc_required" on 403, otherwise absent.</summary>
    [JsonPropertyName("reason")]
    public string? Reason { get; set; }
}

/// <summary>Envelope for GET /api/payment-links/:token's response: {"link": {...}}.</summary>
public sealed class PayLinkStatusPayload
{
    [JsonPropertyName("link")]
    public PaymentLink? Link { get; set; }
}

/// <summary>Outcome of attempting to create an order's payment link, mirrors CreatePaymentLinkResult in mudbase-server.ts.</summary>
public sealed class PaymentLinkCreateResult
{
    public bool Ok { get; private init; }
    public PaymentLink? Link { get; private init; }
    public bool KycRequired { get; private init; }
    public string? ErrorMessage { get; private init; }

    public static PaymentLinkCreateResult Success(PaymentLink link) => new() { Ok = true, Link = link };

    public static PaymentLinkCreateResult NeedsKyc(string message) => new() { Ok = false, KycRequired = true, ErrorMessage = message };

    public static PaymentLinkCreateResult Failed(string message) => new() { Ok = false, ErrorMessage = message };
}
