namespace MudbaseShowcase.Ecommerce.Options;

/// <summary>
/// Every config value this app needs to talk to a provisioned Mudbase project. Bound from the
/// "Mudbase" section of appsettings.json / environment variables — see appsettings.Example.json
/// at the repo root for the full list with descriptions.
/// </summary>
public sealed class MudbaseOptions
{
    public const string SectionName = "Mudbase";

    /// <summary>Mudbase API base URL. Defaults to the public cloud endpoint.</summary>
    public string BaseUrl { get; set; } = "https://cloud.mudbase.dev";

    /// <summary>The Mudbase project ID this storefront is provisioned against.</summary>
    public string ProjectId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "products" collection.</summary>
    public string ProductsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "orders" collection.</summary>
    public string OrdersCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "carts" collection.</summary>
    public string CartsCollectionId { get; set; } = string.Empty;

    /// <summary>
    /// Base URL of the already-deployed Next.js reference storefront, whose
    /// /api/checkout/pay-link route holds the org owner/admin merchant credential needed to
    /// create Payment Links. This app never creates payment links itself — see README "Payment
    /// flow" and "Known limitations".
    /// </summary>
    public string PaymentLinkProxyBaseUrl { get; set; } = "https://mudbase-showcase-ecommerce.vercel.app";

    /// <summary>
    /// Throws with a clear, specific message if any required value was left unset, so a
    /// misconfigured deployment fails at startup instead of surfacing confusing errors deep
    /// inside a request handler.
    /// </summary>
    public void Validate()
    {
        var missing = new List<string>();

        if (string.IsNullOrWhiteSpace(BaseUrl)) missing.Add(nameof(BaseUrl));
        if (string.IsNullOrWhiteSpace(ProjectId)) missing.Add(nameof(ProjectId));
        if (string.IsNullOrWhiteSpace(ProductsCollectionId)) missing.Add(nameof(ProductsCollectionId));
        if (string.IsNullOrWhiteSpace(OrdersCollectionId)) missing.Add(nameof(OrdersCollectionId));
        if (string.IsNullOrWhiteSpace(CartsCollectionId)) missing.Add(nameof(CartsCollectionId));
        if (string.IsNullOrWhiteSpace(PaymentLinkProxyBaseUrl)) missing.Add(nameof(PaymentLinkProxyBaseUrl));

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"Missing required Mudbase configuration values: {string.Join(", ", missing)}. " +
                "Set them under the \"Mudbase\" section of appsettings.json, appsettings.Development.json, " +
                "or the corresponding Mudbase__<Key> environment variables. See appsettings.Example.json.");
        }
    }
}
