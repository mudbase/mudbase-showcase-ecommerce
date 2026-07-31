using System.Text;
using System.Text.RegularExpressions;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>Mirrors web/src/lib/utils.ts's slugify + the random suffix NewProductPage appends so two products with the same name don't collide.</summary>
public static partial class SlugGenerator
{
    public static string Slugify(string value)
    {
        string lower = value.ToLowerInvariant().Trim();
        string dashed = NonAlphanumericRegex().Replace(lower, "-");
        return TrimDashesRegex().Replace(dashed, "");
    }

    public static string GenerateUniqueSlug(string name)
    {
        string suffix = Convert.ToBase64String(Guid.NewGuid().ToByteArray())
            .ToLowerInvariant()
            .Where(char.IsLetterOrDigit)
            .Take(6)
            .Aggregate(new StringBuilder(), (sb, c) => sb.Append(c))
            .ToString();

        return $"{Slugify(name)}-{suffix}";
    }

    [GeneratedRegex("[^a-z0-9]+")]
    private static partial Regex NonAlphanumericRegex();

    [GeneratedRegex("(^-|-$)")]
    private static partial Regex TrimDashesRegex();
}
