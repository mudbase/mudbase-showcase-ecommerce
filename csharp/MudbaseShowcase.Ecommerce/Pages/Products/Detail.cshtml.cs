using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Products;

/// <summary>Single product page, mirrors web/src/app/products/[slug]/page.tsx.</summary>
public sealed class DetailModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly CartService _cart;
    private readonly MudbaseOptions _options;

    public DetailModel(MudbaseDataService data, CartService cart, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _cart = cart;
        _options = options.Value;
    }

    public ProductDocument? Product { get; private set; }

    public IReadOnlyList<string> GalleryImages { get; private set; } = Array.Empty<string>();

    public int? DiscountPercent { get; private set; }

    public bool IsNotFound { get; private set; }

    [BindProperty]
    public int Quantity { get; set; } = 1;

    [TempData]
    public string? AddedMessage { get; set; }

    [TempData]
    public string? AddError { get; set; }

    public async Task OnGetAsync(string slug, CancellationToken cancellationToken)
    {
        await LoadProductAsync(slug, cancellationToken);
    }

    public async Task<IActionResult> OnPostAddToCartAsync(string slug, CancellationToken cancellationToken)
    {
        await LoadProductAsync(slug, cancellationToken);

        if (Product is null)
        {
            IsNotFound = true;
            return Page();
        }

        if (Quantity < 1)
        {
            Quantity = 1;
        }

        try
        {
            await _cart.AddItemAsync(new CartItem
            {
                ProductId = Product.Id,
                Name = Product.Name,
                PriceCents = Product.PriceCents,
                Currency = Product.Currency,
                ImageUrl = Product.ImageUrl,
            }, Quantity, cancellationToken);

            AddedMessage = $"Added {Quantity} × {Product.Name} to your cart.";
        }
        catch (MudbaseApiException ex)
        {
            AddError = "Something went wrong adding this to your cart. Please try again. (" + ex.Message + ")";
        }

        return RedirectToPage(new { slug });
    }

    private async Task LoadProductAsync(string slug, CancellationToken cancellationToken)
    {
        MudbaseListResult<ProductDocument> result;
        try
        {
            result = await _data.ListAsync<ProductDocument>(
                _options.ProductsCollectionId, new Dictionary<string, object?> { ["slug"] = slug }, limit: 1, cancellationToken: cancellationToken);
        }
        catch (MudbaseApiException)
        {
            // Matches the reference app's behavior on any load failure — a shopper never needs to
            // distinguish "doesn't exist" from "couldn't be reached right now" on a product page.
            IsNotFound = true;
            return;
        }

        Product = result.Items.FirstOrDefault();
        if (Product is null)
        {
            IsNotFound = true;
            return;
        }

        List<string> gallery = JsonFieldHelper.Parse(Product.GalleryJson, new List<string>());
        List<string> images = new();
        if (!string.IsNullOrWhiteSpace(Product.ImageUrl)) images.Add(Product.ImageUrl);
        images.AddRange(gallery.Where(url => !string.IsNullOrWhiteSpace(url)));
        GalleryImages = images;

        DiscountPercent = Product.DiscountPercent();
    }
}
