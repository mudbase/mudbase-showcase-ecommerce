using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Orders;

/// <summary>Mirrors web/src/app/orders/[id]/page.tsx.</summary>
public sealed class DetailModel : PageModel
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public DetailModel(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    public OrderDocument? Order { get; private set; }

    public List<OrderLineItem> Items { get; private set; } = new();

    public ShippingAddress? Address { get; private set; }

    public bool IsNotFound { get; private set; }

    public string? LoadError { get; private set; }

    public async Task OnGetAsync(string id, CancellationToken cancellationToken)
    {
        try
        {
            Order = await _data.GetAsync<OrderDocument>(_options.OrdersCollectionId, id, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "This order couldn't be found. (" + ex.Message + ")";
            return;
        }

        if (Order is null)
        {
            IsNotFound = true;
            return;
        }

        Items = JsonFieldHelper.Parse(Order.ItemsJson, new List<OrderLineItem>());
        Address = JsonFieldHelper.Parse<ShippingAddress?>(Order.ShippingAddressJson, null);
    }
}
