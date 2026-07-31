using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Options;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Checkout;

/// <summary>
/// Mirrors web/src/app/checkout/page.tsx: shipping form + inline sign-in for guests, creates the
/// order doc, then calls the payment-link proxy. Payment currency/network are fixed at "USDC" /
/// "POLYGON" — same constants the reference app hardcodes in its checkout submit handler.
/// </summary>
public sealed class IndexModel : PageModel
{
    private const string Currency = "USDC";
    private const string Network = "POLYGON";

    private readonly CartService _cart;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseAuthService _auth;
    private readonly MudbaseDataService _data;
    private readonly PaymentLinkProxyService _payLink;
    private readonly MudbaseOptions _options;

    public IndexModel(
        CartService cart,
        MudbaseSessionAccessor session,
        MudbaseAuthService auth,
        MudbaseDataService data,
        PaymentLinkProxyService payLink,
        IOptions<MudbaseOptions> options)
    {
        _cart = cart;
        _session = session;
        _auth = auth;
        _data = data;
        _payLink = payLink;
        _options = options.Value;
    }

    public IReadOnlyList<CartItem> Items { get; private set; } = Array.Empty<CartItem>();

    public int SubtotalCents { get; private set; }

    public bool IsCustomer { get; private set; }

    public string? ErrorMessage { get; private set; }

    [BindProperty]
    public LoginInput LoginForm { get; set; } = new();

    [BindProperty]
    public RegisterInput RegisterForm { get; set; } = new();

    [BindProperty]
    public ShippingInput Shipping { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        await LoadCartAsync(cancellationToken);
    }

    public async Task<IActionResult> OnPostLoginAsync(CancellationToken cancellationToken)
    {
        await LoadCartAsync(cancellationToken);

        if (!TryValidateModel(LoginForm, nameof(LoginForm)))
        {
            return Page();
        }

        AuthOutcome outcome = await _auth.LoginAsync(LoginForm.Email, LoginForm.Password, cancellationToken);
        if (!outcome.Succeeded)
        {
            ErrorMessage = outcome.ErrorMessage;
            return Page();
        }

        await MigrateCartAsync(cancellationToken);
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRegisterAsync(CancellationToken cancellationToken)
    {
        await LoadCartAsync(cancellationToken);

        if (!RegisterForm.AgreedToTerms)
        {
            ModelState.AddModelError($"{nameof(RegisterForm)}.{nameof(RegisterForm.AgreedToTerms)}",
                "You must agree to the Terms of Service and Privacy Policy.");
        }

        if (!TryValidateModel(RegisterForm, nameof(RegisterForm)))
        {
            return Page();
        }

        AuthOutcome outcome = await _auth.RegisterCustomerAsync(
            RegisterForm.Email, RegisterForm.Password, RegisterForm.FirstName, RegisterForm.LastName, RegisterForm.AgreedToTerms, cancellationToken);

        if (!outcome.Succeeded)
        {
            ErrorMessage = outcome.ErrorMessage;
            return Page();
        }

        await MigrateCartAsync(cancellationToken);
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostPlaceOrderAsync(CancellationToken cancellationToken)
    {
        await LoadCartAsync(cancellationToken);

        if (!IsCustomer)
        {
            ErrorMessage = "Please sign in to place your order.";
            return Page();
        }

        if (Items.Count == 0)
        {
            return RedirectToPage();
        }

        if (!TryValidateModel(Shipping, nameof(Shipping)))
        {
            return Page();
        }

        MudbaseSessionUser user = _session.CurrentUser!;

        List<OrderLineItem> orderItems = Items
            .Select(i => new OrderLineItem { ProductId = i.ProductId, Name = i.Name, PriceCents = i.PriceCents, Quantity = i.Quantity })
            .ToList();

        ShippingAddress address = new()
        {
            FullName = Shipping.FullName,
            Line1 = Shipping.Line1,
            Line2 = Shipping.Line2,
            City = Shipping.City,
            Region = Shipping.Region,
            PostalCode = Shipping.PostalCode,
            Country = Shipping.Country,
        };

        OrderDocument order;
        try
        {
            order = await _data.CreateAsync<OrderDocument>(_options.OrdersCollectionId, new Dictionary<string, object?>
            {
                ["userId"] = user.Id,
                ["itemsJson"] = JsonFieldHelper.Stringify(orderItems),
                ["subtotalCents"] = SubtotalCents,
                ["currency"] = "USD",
                ["orderStatus"] = Models.OrderStatus.AwaitingPayment,
                ["shippingName"] = address.FullName,
                ["shippingAddressJson"] = JsonFieldHelper.Stringify(address),
                ["paymentStatus"] = OrderPaymentStatus.Unpaid,
            }, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            ErrorMessage = "Something went wrong placing your order. Please try again. (" + ex.Message + ")";
            return Page();
        }

        string redirectUrl = $"{Request.Scheme}://{Request.Host}/Orders/Detail/{order.Id}";
        decimal amount = SubtotalCents / 100m;

        PaymentLinkCreateResult result = await _payLink.CreateAsync(order.Id, amount, Currency, Network, redirectUrl, cancellationToken);

        try
        {
            if (result.KycRequired)
            {
                await _data.UpdateAsync<OrderDocument>(_options.OrdersCollectionId, order.Id, new Dictionary<string, object?>
                {
                    ["orderStatus"] = Models.OrderStatus.Pending,
                }, cancellationToken);

                ErrorMessage = result.ErrorMessage ?? "This store's payments are still pending identity verification.";
                return Page();
            }

            if (!result.Ok || result.Link is null)
            {
                ErrorMessage = result.ErrorMessage ?? "Couldn't start payment. Please try again.";
                return Page();
            }

            await _data.UpdateAsync<OrderDocument>(_options.OrdersCollectionId, order.Id, new Dictionary<string, object?>
            {
                ["paymentLinkToken"] = result.Link.Token,
            }, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            // The order itself was created successfully (it's already visible in Orders); only the
            // payment-link bookkeeping update failed. Send the shopper to the order detail page
            // instead of losing the order behind a raw error — they can retry payment from there
            // once "Complete payment" is available again.
            ErrorMessage = "Your order was placed, but something went wrong starting payment. (" + ex.Message + ") Check Orders for your order.";
            return Page();
        }

        try
        {
            await _cart.ClearAsync(cancellationToken);
        }
        catch (MudbaseApiException)
        {
            // Non-fatal: the order and payment link are already created and the shopper is about
            // to leave this cart behind anyway — a stale cart is a cosmetic issue, not a reason to
            // block the redirect to payment.
        }

        return RedirectToPage("/Checkout/Pay", new { token = result.Link.Token });
    }

    private async Task MigrateCartAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not null)
        {
            await _cart.MigrateGuestCartToServerAsync(user.Id, cancellationToken);
        }
    }

    private async Task LoadCartAsync(CancellationToken cancellationToken)
    {
        try
        {
            Items = await _cart.GetItemsAsync(cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            Items = Array.Empty<CartItem>();
            ErrorMessage = "Couldn't load your cart right now. (" + ex.Message + ")";
        }

        SubtotalCents = CartService.SubtotalCents(Items);
        IsCustomer = _session.CurrentUser is { IsCustomer: true };
    }

    public sealed class LoginInput
    {
        [Required(ErrorMessage = "Email is required"), EmailAddress(ErrorMessage = "Enter a valid email address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        public string Password { get; set; } = string.Empty;
    }

    public sealed class RegisterInput
    {
        [Required(ErrorMessage = "First name is required")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last name is required")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email is required"), EmailAddress(ErrorMessage = "Enter a valid email address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        [MinLength(8, ErrorMessage = "Password must be at least 8 characters")]
        public string Password { get; set; } = string.Empty;

        public bool AgreedToTerms { get; set; }
    }

    public sealed class ShippingInput
    {
        [Required(ErrorMessage = "Full name is required")]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Address is required")]
        public string Line1 { get; set; } = string.Empty;

        public string? Line2 { get; set; }

        [Required(ErrorMessage = "City is required")]
        public string City { get; set; } = string.Empty;

        [Required(ErrorMessage = "State/region is required")]
        public string Region { get; set; } = string.Empty;

        [Required(ErrorMessage = "Postal code is required")]
        public string PostalCode { get; set; } = string.Empty;

        [Required(ErrorMessage = "Country is required")]
        public string Country { get; set; } = string.Empty;
    }
}
