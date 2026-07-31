using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Seller.Products;

/// <summary>Mirrors web/src/app/seller/products/new/page.tsx.</summary>
public sealed class NewModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;

    public NewModel(MudbaseDataService data, MudbaseSessionAccessor session, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _session = session;
        _options = options.Value;
    }

    [BindProperty]
    public ProductFormInput Input { get; set; } = new();

    public string? SubmitError { get; private set; }

    public IActionResult OnGet()
    {
        if (_session.CurrentUser is not { IsSeller: true })
        {
            return RedirectToPage("/Index");
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSeller: true })
        {
            return RedirectToPage("/Index");
        }

        List<string> galleryUrls = Input.ValidateAndCollectGalleryUrls(ModelState, nameof(Input));

        if (!ModelState.IsValid)
        {
            return Page();
        }

        Dictionary<string, object?> data = Input.ToDataDictionary(galleryUrls, user.Id);
        data["slug"] = SlugGenerator.GenerateUniqueSlug(Input.Name);

        try
        {
            await _data.CreateAsync<ProductDocument>(_options.ProductsCollectionId, data, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            SubmitError = "Couldn't save this product. Please try again. (" + ex.Message + ")";
            return Page();
        }

        return RedirectToPage("/Seller/Index");
    }
}
