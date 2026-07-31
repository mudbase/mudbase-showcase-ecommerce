using System.Globalization;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Deliberately not `decimal.ToString("C")` — that format specifier always renders the *culture's*
/// currency symbol (e.g. "$" for en-US) regardless of the `currency` argument passed in, which
/// would silently mislabel non-USD amounts. Mirrors web/src/lib/utils.ts's formatMoney closely
/// enough for the currencies this app actually displays (USD for products/orders; USDC only ever
/// appears as a payment-link label, never formatted through this helper).
/// </summary>
public static class MoneyFormatter
{
    public static string Format(int cents, string currency)
    {
        decimal amount = cents / 100m;
        string normalized = currency.Trim().ToUpperInvariant();
        string prefix = normalized == "USD" ? "$" : normalized + " ";
        return prefix + amount.ToString("F2", CultureInfo.InvariantCulture);
    }

    public static string FormatDate(DateTimeOffset value) => value.ToLocalTime().ToString("MMM d, yyyy h:mm tt", CultureInfo.InvariantCulture);

    /// <summary>Last 6 characters of a Mudbase document ID, upper-cased — mirrors `order._id.slice(-6).toUpperCase()`. Pulled out to a plain method rather than inline range syntax so Razor views can call it without `@` parsing surprises around `[^..]`.</summary>
    public static string ShortId(string id) => (id.Length <= 6 ? id : id[^6..]).ToUpperInvariant();
}
