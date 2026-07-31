using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using MudbaseShowcase.Ecommerce.Models;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Creating a Mudbase Payment Link requires an org owner/admin bearer credential — there is no
/// API-key path for it, and a project end-user's JWT (customer or seller) can never carry an org
/// role. To avoid every per-language reimplementation of this reference storefront independently
/// rotating the same single-use merchant refresh token (a real race condition if multiple apps run
/// concurrently), this app does NOT create payment links itself. Instead it calls the
/// already-deployed Next.js reference app's own proxy route, which holds that merchant credential.
/// See README "Payment flow" and "Known limitations".
/// </summary>
public sealed class PaymentLinkProxyService
{
    private readonly HttpClient _proxyClient;
    private readonly HttpClient _publicMudbaseClient;
    private readonly ILogger<PaymentLinkProxyService> _logger;

    public PaymentLinkProxyService(IHttpClientFactory httpClientFactory, ILogger<PaymentLinkProxyService> logger)
    {
        _proxyClient = httpClientFactory.CreateClient(HttpClientNames.PayLinkProxy);
        _publicMudbaseClient = httpClientFactory.CreateClient(HttpClientNames.MudbasePublic);
        _logger = logger;
    }

    public async Task<PaymentLinkCreateResult> CreateAsync(
        string orderId, decimal amountUsd, string currency, string network, string redirectUrl, CancellationToken cancellationToken)
    {
        var payload = new
        {
            orderId,
            amount = amountUsd.ToString("F2", CultureInfo.InvariantCulture),
            currency,
            network,
            redirectUrl,
        };

        HttpResponseMessage response;
        try
        {
            response = await _proxyClient.PostAsJsonAsync("/api/checkout/pay-link", payload, MudbaseJson.Options, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Could not reach the payment-link proxy for order {OrderId}", orderId);
            return PaymentLinkCreateResult.Failed("Couldn't start payment — the payment service is temporarily unreachable.");
        }

        using (response)
        {
            string raw = await response.Content.ReadAsStringAsync(cancellationToken);

            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                PayLinkErrorPayload? forbidden = SafeDeserialize<PayLinkErrorPayload>(raw);
                if (forbidden?.Reason == "kyc_required")
                {
                    return PaymentLinkCreateResult.NeedsKyc(
                        forbidden.Error ?? "This store's identity verification is still pending — payments are not yet available.");
                }
            }

            if (!response.IsSuccessStatusCode)
            {
                PayLinkErrorPayload? error = SafeDeserialize<PayLinkErrorPayload>(raw);
                return PaymentLinkCreateResult.Failed(error?.Error ?? $"Couldn't start payment ({(int)response.StatusCode}).");
            }

            PayLinkCreateSuccessPayload? success = SafeDeserialize<PayLinkCreateSuccessPayload>(raw);
            if (success?.Link is not { Token.Length: > 0 } link)
            {
                return PaymentLinkCreateResult.Failed("Payment link response was malformed.");
            }

            return PaymentLinkCreateResult.Success(link);
        }
    }

    /// <summary>Public, unauthenticated read — polled by the payment status page until the link reaches a terminal status.</summary>
    public async Task<PaymentLink?> GetPublicStatusAsync(string token, CancellationToken cancellationToken)
    {
        using HttpResponseMessage response = await _publicMudbaseClient.GetAsync($"/api/payment-links/{Uri.EscapeDataString(token)}", cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string raw = await response.Content.ReadAsStringAsync(cancellationToken);
        PayLinkStatusPayload? payload = SafeDeserialize<PayLinkStatusPayload>(raw);
        return payload?.Link;
    }

    private static T? SafeDeserialize<T>(string raw) where T : class
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        try
        {
            return JsonSerializer.Deserialize<T>(raw, MudbaseJson.Options);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
