using System.Text.Json.Serialization;

namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>
/// Maps a document from the "carts" Mudbase collection. One doc per (customer) user — see
/// <see cref="MudbaseShowcase.Ecommerce.Services.CartService"/> for the read-then-create-or-update
/// pattern this requires (Mudbase has no native upsert).
/// </summary>
public sealed class CartDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    /// <summary>JSON-array-as-string of <see cref="CartItem"/>.</summary>
    [JsonPropertyName("itemsJson")]
    public string ItemsJson { get; set; } = "[]";
}

public sealed class CartItem
{
    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("priceCents")]
    public int PriceCents { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    [JsonPropertyName("imageUrl")]
    public string? ImageUrl { get; set; }

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }

    public int LineTotalCents => PriceCents * Quantity;
}
