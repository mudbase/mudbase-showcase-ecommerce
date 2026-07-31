using System.Text.Json.Serialization;

namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>
/// Maps a document from the "orders" Mudbase collection. The status field is named
/// "orderStatus", not "status" — Mudbase's server-side role-assignment guard
/// (enforceServerRoleAssignment.js) treats a literal "status" field on ANY collection as a
/// protected role field and rejects writes from non-owner/admin callers, i.e. every project
/// end-user including sellers. Real platform constraint, not a typo — mirrors
/// web/src/types/order.ts exactly. See README "Known limitations".
/// </summary>
public sealed class OrderDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    /// <summary>JSON-array-as-string of <see cref="OrderLineItem"/>.</summary>
    [JsonPropertyName("itemsJson")]
    public string ItemsJson { get; set; } = "[]";

    [JsonPropertyName("subtotalCents")]
    public int SubtotalCents { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    [JsonPropertyName("orderStatus")]
    public string OrderStatus { get; set; } = Models.OrderStatus.Pending;

    [JsonPropertyName("shippingName")]
    public string? ShippingName { get; set; }

    /// <summary>JSON-object-as-string of <see cref="ShippingAddress"/>.</summary>
    [JsonPropertyName("shippingAddressJson")]
    public string? ShippingAddressJson { get; set; }

    [JsonPropertyName("paymentLinkToken")]
    public string? PaymentLinkToken { get; set; }

    [JsonPropertyName("paymentStatus")]
    public string PaymentStatus { get; set; } = Models.OrderPaymentStatus.Unpaid;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class OrderLineItem
{
    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("priceCents")]
    public int PriceCents { get; set; }

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }
}

public sealed class ShippingAddress
{
    [JsonPropertyName("fullName")]
    public string FullName { get; set; } = string.Empty;

    [JsonPropertyName("line1")]
    public string Line1 { get; set; } = string.Empty;

    [JsonPropertyName("line2")]
    public string? Line2 { get; set; }

    [JsonPropertyName("city")]
    public string City { get; set; } = string.Empty;

    [JsonPropertyName("region")]
    public string Region { get; set; } = string.Empty;

    [JsonPropertyName("postalCode")]
    public string PostalCode { get; set; } = string.Empty;

    [JsonPropertyName("country")]
    public string Country { get; set; } = string.Empty;
}

/// <summary>
/// Plain string constants rather than a C# enum: Mudbase stores these as free-form strings
/// (e.g. "awaiting_payment"), and a JsonStringEnumConverter would need per-value naming overrides
/// to round-trip correctly. Mirrors the TS `type OrderStatus = "pending" | ... ` union exactly.
/// </summary>
public static class OrderStatus
{
    public const string Pending = "pending";
    public const string AwaitingPayment = "awaiting_payment";
    public const string Paid = "paid";
    public const string Shipped = "shipped";
    public const string Delivered = "delivered";
    public const string Cancelled = "cancelled";

    public static readonly IReadOnlyList<string> All = new[] { Pending, AwaitingPayment, Paid, Shipped, Delivered, Cancelled };

    public static string Label(string status) => status switch
    {
        Pending => "Pending",
        AwaitingPayment => "Awaiting payment",
        Paid => "Paid",
        Shipped => "Shipped",
        Delivered => "Delivered",
        Cancelled => "Cancelled",
        _ => status,
    };

    /// <summary>The seller fulfillment queue's one-tap "next status" action, mirrors NEXT_STATUS in SellerOrderQueue.tsx.</summary>
    public static string? NextStatus(string status) => status switch
    {
        Paid => Shipped,
        Shipped => Delivered,
        _ => null,
    };
}

public static class OrderPaymentStatus
{
    public const string Unpaid = "unpaid";
    public const string Paid = "paid";
    public const string Expired = "expired";
    public const string Cancelled = "cancelled";
}
