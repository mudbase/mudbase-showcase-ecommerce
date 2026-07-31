using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Orders;

/// <summary>Mirrors web/src/app/orders/page.tsx + OrderList.tsx.</summary>
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

    public string? LoadError { get; private set; }

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            Orders = Array.Empty<OrderDocument>();
            return;
        }

        try
        {
            MudbaseListResult<OrderDocument> result = await _data.ListAsync<OrderDocument>(
                _options.OrdersCollectionId, new Dictionary<string, object?> { ["userId"] = user.Id },
                sort: "-createdAt", cancellationToken: cancellationToken);
            Orders = result.Items;
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load your orders right now. (" + ex.Message + ")";
        }
    }
}
