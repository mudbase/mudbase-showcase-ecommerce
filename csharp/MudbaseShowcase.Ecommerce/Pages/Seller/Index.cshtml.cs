using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Seller;

/// <summary>
/// Seller dashboard: fulfillment queue + product list, mirrors web/src/app/seller/page.tsx +
/// SellerOrderQueue.tsx + ProductTable.tsx. No realtime Socket.IO port here — see README
/// "Known limitations"; the queue is refreshed on page load / an explicit Refresh link instead.
/// </summary>
public sealed class IndexModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;

    public IndexModel(MudbaseDataService data, MudbaseSessionAccessor session, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _session = session;
        _options = options.Value;
    }

    public IReadOnlyList<OrderDocument> Orders { get; private set; } = Array.Empty<OrderDocument>();

    public IReadOnlyList<ProductDocument> Products { get; private set; } = Array.Empty<ProductDocument>();

    public string? OrdersError { get; private set; }

    public string? ProductsError { get; private set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        if (!IsSeller())
        {
            return RedirectToPage("/Index");
        }

        try
        {
            MudbaseListResult<OrderDocument> orders = await _data.ListAsync<OrderDocument>(
                _options.OrdersCollectionId, sort: "-createdAt", limit: 100, cancellationToken: cancellationToken);
            Orders = orders.Items;
        }
        catch (MudbaseApiException ex)
        {
            OrdersError = "Couldn't load orders. (" + ex.Message + ")";
        }

        try
        {
            MudbaseListResult<ProductDocument> products = await _data.ListAsync<ProductDocument>(
                _options.ProductsCollectionId, sort: "-createdAt", limit: 100, cancellationToken: cancellationToken);
            Products = products.Items;
        }
        catch (MudbaseApiException ex)
        {
            ProductsError = "Couldn't load products. (" + ex.Message + ")";
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAdvanceStatusAsync(string orderId, string nextStatus, CancellationToken cancellationToken)
    {
        if (!IsSeller())
        {
            return RedirectToPage("/Index");
        }

        try
        {
            await _data.UpdateAsync<OrderDocument>(_options.OrdersCollectionId, orderId, new Dictionary<string, object?>
            {
                ["orderStatus"] = nextStatus,
            }, cancellationToken);
        }
        catch (MudbaseApiException)
        {
            // Swallowed by design here: the queue reloads regardless, and will simply keep
            // showing the order at its previous status if the update didn't take — no separate
            // error channel exists on this list view for a single row's action.
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostDeleteProductAsync(string productId, CancellationToken cancellationToken)
    {
        if (!IsSeller())
        {
            return RedirectToPage("/Index");
        }

        try
        {
            await _data.DeleteAsync(_options.ProductsCollectionId, productId, cancellationToken);
        }
        catch (MudbaseApiException)
        {
        }

        return RedirectToPage();
    }

    private bool IsSeller() => _session.CurrentUser is { IsSeller: true };
}
