using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Cart logic, direct port of web/src/hooks/useCart.ts's server/guest split.
///
/// A "customer" application role, not an anonymous or unauthenticated session, is required to
/// persist a cart in the `carts` collection — Mudbase's ownership-conditioned permission only
/// grants create/read/update/delete to the `customer` customRole. A guest session (anonymous JWT,
/// no customRole) is denied. This keeps the cart in the browser's server-side session state until
/// the shopper has a real customer account, then hands off to the server — see
/// <see cref="MigrateGuestCartToServerAsync"/>, called right after registration/login succeeds in
/// the checkout flow.
/// </summary>
public sealed class CartService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;

    public CartService(MudbaseDataService data, MudbaseSessionAccessor session, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _session = session;
        _options = options.Value;
    }

    public async Task<IReadOnlyList<CartItem>> GetItemsAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is { IsCustomer: true })
        {
            CartDocument? cart = await GetCustomerCartAsync(user.Id, cancellationToken);
            return cart is null ? Array.Empty<CartItem>() : JsonFieldHelper.Parse(cart.ItemsJson, new List<CartItem>());
        }

        return ReadGuestCart();
    }

    public static int SubtotalCents(IReadOnlyList<CartItem> items) => items.Sum(i => i.LineTotalCents);

    public async Task AddItemAsync(CartItem newItem, int quantity, CancellationToken cancellationToken)
    {
        List<CartItem> items = (await GetItemsAsync(cancellationToken)).ToList();
        int existingIndex = items.FindIndex(i => i.ProductId == newItem.ProductId);

        if (existingIndex >= 0)
        {
            CartItem existing = items[existingIndex];
            items[existingIndex] = new CartItem
            {
                ProductId = existing.ProductId,
                Name = existing.Name,
                PriceCents = existing.PriceCents,
                Currency = existing.Currency,
                ImageUrl = existing.ImageUrl,
                Quantity = existing.Quantity + quantity,
            };
        }
        else
        {
            items.Add(new CartItem
            {
                ProductId = newItem.ProductId,
                Name = newItem.Name,
                PriceCents = newItem.PriceCents,
                Currency = newItem.Currency,
                ImageUrl = newItem.ImageUrl,
                Quantity = quantity,
            });
        }

        await PersistAsync(items, cancellationToken);
    }

    public async Task UpdateQuantityAsync(string productId, int quantity, CancellationToken cancellationToken)
    {
        List<CartItem> items = (await GetItemsAsync(cancellationToken)).ToList();
        items = quantity <= 0
            ? items.Where(i => i.ProductId != productId).ToList()
            : items.Select(i => i.ProductId == productId ? WithQuantity(i, quantity) : i).ToList();

        await PersistAsync(items, cancellationToken);
    }

    public async Task RemoveItemAsync(string productId, CancellationToken cancellationToken)
    {
        List<CartItem> items = (await GetItemsAsync(cancellationToken)).Where(i => i.ProductId != productId).ToList();
        await PersistAsync(items, cancellationToken);
    }

    public async Task ClearAsync(CancellationToken cancellationToken)
    {
        await PersistAsync(new List<CartItem>(), cancellationToken);
    }

    /// <summary>Called once, right after a guest completes real customer registration or signs in at checkout.</summary>
    public async Task MigrateGuestCartToServerAsync(string userId, CancellationToken cancellationToken)
    {
        List<CartItem> guestItems = ReadGuestCart();
        if (guestItems.Count == 0)
        {
            return;
        }

        CartDocument? existing = await GetCustomerCartAsync(userId, cancellationToken);

        if (existing is null)
        {
            await _data.CreateAsync<CartDocument>(_options.CartsCollectionId, new Dictionary<string, object?>
            {
                ["userId"] = userId,
                ["itemsJson"] = JsonFieldHelper.Stringify(guestItems),
            }, cancellationToken);
            _session.ClearGuestCart();
            return;
        }

        List<CartItem> merged = JsonFieldHelper.Parse(existing.ItemsJson, new List<CartItem>());
        foreach (CartItem guestItem in guestItems)
        {
            int idx = merged.FindIndex(i => i.ProductId == guestItem.ProductId);
            merged = idx >= 0
                ? merged.Select((i, index) => index == idx ? WithQuantity(i, i.Quantity + guestItem.Quantity) : i).ToList()
                : merged.Append(guestItem).ToList();
        }

        await _data.UpdateAsync<CartDocument>(_options.CartsCollectionId, existing.Id, new Dictionary<string, object?>
        {
            ["itemsJson"] = JsonFieldHelper.Stringify(merged),
        }, cancellationToken);

        _session.ClearGuestCart();
    }

    private static CartItem WithQuantity(CartItem item, int quantity) => new()
    {
        ProductId = item.ProductId,
        Name = item.Name,
        PriceCents = item.PriceCents,
        Currency = item.Currency,
        ImageUrl = item.ImageUrl,
        Quantity = quantity,
    };

    private List<CartItem> ReadGuestCart() => JsonFieldHelper.Parse(_session.GetGuestCartJson(), new List<CartItem>());

    private void WriteGuestCart(List<CartItem> items) => _session.SetGuestCartJson(JsonFieldHelper.Stringify(items));

    private async Task<CartDocument?> GetCustomerCartAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<CartDocument> result = await _data.ListAsync<CartDocument>(
            _options.CartsCollectionId, new Dictionary<string, object?> { ["userId"] = userId }, limit: 1, cancellationToken: cancellationToken);
        return result.Items.FirstOrDefault();
    }

    private async Task PersistAsync(List<CartItem> items, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsCustomer: true })
        {
            WriteGuestCart(items);
            return;
        }

        string itemsJson = JsonFieldHelper.Stringify(items);

        // Re-fetch the authoritative cart right before deciding create-vs-update rather than
        // trusting any caller-held reference — a returning customer may already have a server cart
        // from an earlier session, and Mudbase has no native upsert.
        CartDocument? existing = await GetCustomerCartAsync(user.Id, cancellationToken);

        if (existing is not null)
        {
            await _data.UpdateAsync<CartDocument>(_options.CartsCollectionId, existing.Id, new Dictionary<string, object?>
            {
                ["itemsJson"] = itemsJson,
            }, cancellationToken);
        }
        else
        {
            await _data.CreateAsync<CartDocument>(_options.CartsCollectionId, new Dictionary<string, object?>
            {
                ["userId"] = user.Id,
                ["itemsJson"] = itemsJson,
            }, cancellationToken);
        }
    }
}
