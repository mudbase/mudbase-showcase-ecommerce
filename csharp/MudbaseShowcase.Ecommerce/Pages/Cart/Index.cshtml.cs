using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Cart;

/// <summary>Mirrors web/src/app/cart/page.tsx + CartLineItems.tsx + CartSummary.tsx.</summary>
public sealed class IndexModel : PageModel
{
    private readonly CartService _cart;

    public IndexModel(CartService cart)
    {
        _cart = cart;
    }

    public IReadOnlyList<CartItem> Items { get; private set; } = Array.Empty<CartItem>();

    public int SubtotalCents { get; private set; }

    public string Currency { get; private set; } = "USD";

    public string? LoadError { get; private set; }

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        await LoadAsync(cancellationToken);
    }

    public async Task<IActionResult> OnPostUpdateQuantityAsync(string productId, int quantity, CancellationToken cancellationToken)
    {
        try
        {
            await _cart.UpdateQuantityAsync(productId, quantity, cancellationToken);
        }
        catch (MudbaseApiException)
        {
            // Falls through to a plain reload; the cart page will simply show the pre-update
            // quantities rather than a raw error page for what's normally a transient hiccup.
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRemoveAsync(string productId, CancellationToken cancellationToken)
    {
        try
        {
            await _cart.RemoveItemAsync(productId, cancellationToken);
        }
        catch (MudbaseApiException)
        {
        }

        return RedirectToPage();
    }

    private async Task LoadAsync(CancellationToken cancellationToken)
    {
        try
        {
            Items = await _cart.GetItemsAsync(cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load your cart right now. (" + ex.Message + ")";
            Items = Array.Empty<CartItem>();
        }

        SubtotalCents = CartService.SubtotalCents(Items);
        Currency = Items.Count > 0 ? Items[0].Currency : "USD";
    }
}
