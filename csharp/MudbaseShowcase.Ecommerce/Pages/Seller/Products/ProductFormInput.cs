using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Seller.Products;

/// <summary>
/// Shared by New.cshtml.cs and Edit.cshtml.cs, mirrors web/src/components/seller/ProductForm.tsx.
/// Gallery photos are a fixed set of optional URL inputs rather than a client-side dynamic
/// field array (React's useFieldArray) — same MAX_GALLERY_PHOTOS cap (8), simpler to render as
/// plain server-rendered inputs without extra client JS.
/// </summary>
public sealed class ProductFormInput
{
    public const int MaxGalleryPhotos = 8;

    [Required(ErrorMessage = "Name is required")]
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Price can't be negative")]
    public int PriceCents { get; set; }

    public int? CompareAtPriceCents { get; set; }

    [Required]
    public string Currency { get; set; } = "USD";

    public string? ImageUrl { get; set; }

    public string? Category { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Stock can't be negative")]
    public int Stock { get; set; }

    public bool IsActive { get; set; } = true;

    public List<string?> GalleryUrls { get; set; } = Enumerable.Repeat<string?>(null, MaxGalleryPhotos).ToList();

    /// <summary>Validates cross-field and gallery-URL rules that data annotations can't express, adding to the caller's ModelState.</summary>
    public List<string> ValidateAndCollectGalleryUrls(ModelStateDictionary modelState, string prefix)
    {
        if (CompareAtPriceCents is { } compareAt && compareAt <= PriceCents)
        {
            modelState.AddModelError($"{prefix}.{nameof(CompareAtPriceCents)}", "Compare-at price must be higher than the current price");
        }

        if (!string.IsNullOrWhiteSpace(ImageUrl) && !Uri.TryCreate(ImageUrl, UriKind.Absolute, out _))
        {
            modelState.AddModelError($"{prefix}.{nameof(ImageUrl)}", "Enter a valid image URL");
        }

        List<string> validGalleryUrls = new();
        for (int i = 0; i < GalleryUrls.Count; i++)
        {
            string? url = GalleryUrls[i]?.Trim();
            if (string.IsNullOrEmpty(url)) continue;

            if (!Uri.TryCreate(url, UriKind.Absolute, out _))
            {
                modelState.AddModelError($"{prefix}.{nameof(GalleryUrls)}[{i}]", "Enter a valid image URL");
                continue;
            }

            validGalleryUrls.Add(url);
        }

        return validGalleryUrls;
    }

    public Dictionary<string, object?> ToDataDictionary(IReadOnlyList<string> galleryUrls, string? sellerId = null)
    {
        var data = new Dictionary<string, object?>
        {
            ["name"] = Name,
            ["description"] = Description,
            ["priceCents"] = PriceCents,
            ["compareAtPriceCents"] = CompareAtPriceCents,
            ["currency"] = Currency,
            ["imageUrl"] = string.IsNullOrWhiteSpace(ImageUrl) ? null : ImageUrl,
            ["category"] = Category,
            ["stock"] = Stock,
            ["isActive"] = IsActive,
            ["galleryJson"] = JsonFieldHelper.Stringify(galleryUrls),
        };

        if (sellerId is not null)
        {
            data["sellerId"] = sellerId;
        }

        return data;
    }
}
