namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>Named HttpClient identifiers used outside the Mudbase SDK's own generated typed clients.</summary>
public static class HttpClientNames
{
    /// <summary>Direct, handler-free HTTP access to the Mudbase base URL — used by TokenRefreshHandler's POST /api/auth/refresh call so a refresh can never recurse through its own 401-retry pipeline.</summary>
    public const string MudbaseRaw = "MudbaseRaw";

    /// <summary>The deployed reference web app's own domain, for the payment-link creation proxy.</summary>
    public const string PayLinkProxy = "PayLinkProxy";

    /// <summary>Direct HTTP access to Mudbase for the public, unauthenticated payment-link status read.</summary>
    public const string MudbasePublic = "MudbasePublic";
}
