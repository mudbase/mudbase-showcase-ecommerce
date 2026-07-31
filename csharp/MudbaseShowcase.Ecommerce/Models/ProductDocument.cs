using System.Text.Json.Serialization;

namespace MudbaseShowcase.Ecommerce.Models;

/// <summary>
/// Maps a document from the "products" Mudbase collection. Field names mirror the reference
/// Next.js implementation's `products` schema exactly (see web/src/types/product.ts) so this is a
/// faithful port, not a reinterpretation.
/// </summary>
public sealed class ProductDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("slug")]
    public string Slug { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("priceCents")]
    public int PriceCents { get; set; }

    [JsonPropertyName("compareAtPriceCents")]
    public int? CompareAtPriceCents { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    [JsonPropertyName("imageUrl")]
    public string? ImageUrl { get; set; }

    /// <summary>
    /// JSON-array-as-string of extra gallery image URLs. Mudbase Collection fields have no
    /// native array type, so multi-image galleries are JSON-encoded strings parsed at the edges
    /// via <see cref="MudbaseShowcase.Ecommerce.Services.JsonFieldHelper"/> — see README "Known
    /// limitations".
    /// </summary>
    [JsonPropertyName("galleryJson")]
    public string? GalleryJson { get; set; }

    [JsonPropertyName("category")]
    public string? Category { get; set; }

    [JsonPropertyName("stock")]
    public int Stock { get; set; }

    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; }

    [JsonPropertyName("sellerId")]
    public string? SellerId { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>Percent discount vs. <see cref="CompareAtPriceCents"/>, or null if there isn't one.</summary>
    public int? DiscountPercent()
    {
        if (CompareAtPriceCents is not { } compareAt || compareAt <= PriceCents) return null;
        return (int)Math.Round((1 - (double)PriceCents / compareAt) * 100);
    }
}
