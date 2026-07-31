using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages.Checkout;

/// <summary>
/// Payment status page, mirrors web/src/app/checkout/[token]/page.tsx + PaymentLinkPanel.tsx +
/// usePaymentLinkStatus.ts. The public GET /api/payment-links/:token read needs no auth, so the
/// OnGetStatus handler below is what the page's own polling JS calls every few seconds until the
/// link reaches a terminal status (paid/expired/cancelled).
/// </summary>
public sealed class PayModel : PageModel
{
    private readonly PaymentLinkProxyService _payLink;

    public PayModel(PaymentLinkProxyService payLink)
    {
        _payLink = payLink;
    }

    public string Token { get; private set; } = string.Empty;

    public PaymentLink? Link { get; private set; }

    public string? LoadError { get; private set; }

    public async Task OnGetAsync(string token, CancellationToken cancellationToken)
    {
        Token = token;
        Link = await _payLink.GetPublicStatusAsync(token, cancellationToken);
        if (Link is null)
        {
            LoadError = "Payment link not available.";
        }
    }

    /// <summary>JSON endpoint the page's own polling script hits — avoids a full page reload every 4 seconds.</summary>
    public async Task<JsonResult> OnGetStatusAsync(string token, CancellationToken cancellationToken)
    {
        PaymentLink? link = await _payLink.GetPublicStatusAsync(token, cancellationToken);
        if (link is null)
        {
            return new JsonResult(new { found = false }) { StatusCode = 404 };
        }

        return new JsonResult(new
        {
            found = true,
            status = link.Status,
            amount = link.Amount,
            currency = link.Currency,
            network = link.Network,
            address = link.Address,
        });
    }
}
