using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Seller.Products;

/// <summary>Mirrors web/src/app/seller/products/[id]/edit/page.tsx.</summary>
public sealed class EditModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;

    public EditModel(MudbaseDataService data, MudbaseSessionAccessor session, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _session = session;
        _options = options.Value;
    }

    [BindProperty]
    public ProductFormInput Input { get; set; } = new();

    public bool IsNotFound { get; private set; }

    public string? SubmitError { get; private set; }

    public async Task<IActionResult> OnGetAsync(string id, CancellationToken cancellationToken)
    {
        if (_session.CurrentUser is not { IsSeller: true })
        {
            return RedirectToPage("/Index");
        }

        ProductDocument? product;
        try
        {
            product = await _data.GetAsync<ProductDocument>(_options.ProductsCollectionId, id, cancellationToken);
        }
        catch (MudbaseApiException)
        {
            IsNotFound = true;
            return Page();
        }

        if (product is null)
        {
            IsNotFound = true;
            return Page();
        }

        List<string> gallery = JsonFieldHelper.Parse(product.GalleryJson, new List<string>());
        List<string?> galleryInputs = Enumerable.Repeat<string?>(null, ProductFormInput.MaxGalleryPhotos).ToList();
        for (int i = 0; i < gallery.Count && i < galleryInputs.Count; i++)
        {
            galleryInputs[i] = gallery[i];
        }

        Input = new ProductFormInput
        {
            Name = product.Name,
            Description = product.Description ?? string.Empty,
            PriceCents = product.PriceCents,
            CompareAtPriceCents = product.CompareAtPriceCents,
            Currency = product.Currency,
            ImageUrl = product.ImageUrl ?? string.Empty,
            Category = product.Category ?? string.Empty,
            Stock = product.Stock,
            IsActive = product.IsActive,
            GalleryUrls = galleryInputs,
        };

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(string id, CancellationToken cancellationToken)
    {
        if (_session.CurrentUser is not { IsSeller: true })
        {
            return RedirectToPage("/Index");
        }

        List<string> galleryUrls = Input.ValidateAndCollectGalleryUrls(ModelState, nameof(Input));

        if (!ModelState.IsValid)
        {
            return Page();
        }

        try
        {
            await _data.UpdateAsync<ProductDocument>(_options.ProductsCollectionId, id, Input.ToDataDictionary(galleryUrls), cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            SubmitError = "Couldn't save this product. Please try again. (" + ex.Message + ")";
            return Page();
        }

        return RedirectToPage("/Seller/Index");
    }
}
