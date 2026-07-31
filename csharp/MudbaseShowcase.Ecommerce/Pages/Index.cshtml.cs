using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages;

/// <summary>Product catalog: list + category filter, mirrors web/src/app/page.tsx + ProductGrid.tsx.</summary>
public sealed class IndexModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public IndexModel(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    public IReadOnlyList<ProductDocument> Products { get; private set; } = Array.Empty<ProductDocument>();

    public IReadOnlyList<string> Categories { get; private set; } = Array.Empty<string>();

    [BindProperty(SupportsGet = true)]
    public string? Category { get; set; }

    public string? LoadError { get; private set; }

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var filter = new Dictionary<string, object?> { ["isActive"] = true };
        if (!string.IsNullOrWhiteSpace(Category))
        {
            filter["category"] = Category;
        }

        try
        {
            MudbaseListResult<ProductDocument> result = await _data.ListAsync<ProductDocument>(
                _options.ProductsCollectionId, filter, sort: "-createdAt", limit: 60, cancellationToken: cancellationToken);
            Products = result.Items;

            // The category filter's option list is derived from whatever's currently in the
            // unfiltered catalog view, same as ProductGrid.tsx — when a category is already
            // selected we still need the full set to render the filter row, so re-fetch it
            // unfiltered by category (still isActive-only) for that purpose.
            MudbaseListResult<ProductDocument> allActive = string.IsNullOrWhiteSpace(Category)
                ? result
                : await _data.ListAsync<ProductDocument>(
                    _options.ProductsCollectionId, new Dictionary<string, object?> { ["isActive"] = true },
                    sort: "-createdAt", limit: 60, cancellationToken: cancellationToken);

            Categories = allActive.Items
                .Select(p => p.Category)
                .Where(c => !string.IsNullOrWhiteSpace(c))
                .Select(c => c!)
                .Distinct()
                .OrderBy(c => c, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load the catalog right now. Try refreshing. (" + ex.Message + ")";
        }
    }
}
