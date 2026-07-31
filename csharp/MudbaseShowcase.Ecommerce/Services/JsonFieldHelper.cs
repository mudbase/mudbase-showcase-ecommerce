using System.Text.Json;

namespace MudbaseShowcase.Ecommerce.Services;

/// <summary>
/// Mudbase Collection fields have a fixed type enum (string, number, boolean, date, email, url,
/// enum, reference) with no native array/object type. Anything shaped like a list or a nested
/// record (order line items, a shipping address, extra product images) is stored as a JSON string
/// in a `string` field and parsed at the edges — a real, documented constraint of the platform's
/// Collections feature. Direct port of web/src/lib/json-field.ts.
/// </summary>
public static class JsonFieldHelper
{
    public static T Parse<T>(string? value, T fallback)
    {
        if (string.IsNullOrWhiteSpace(value)) return fallback;
        try
        {
            return JsonSerializer.Deserialize<T>(value, MudbaseJson.Options) ?? fallback;
        }
        catch (JsonException)
        {
            return fallback;
        }
    }

    public static string Stringify<T>(T value) => JsonSerializer.Serialize(value, MudbaseJson.Options);
}
