package dev.mudbase.showcase.ecommerce.mudbase;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;

/**
 * Mudbase collection fields have a fixed type enum (string, number, boolean, date, email, url,
 * enum, reference) with no native array/object type. Anything shaped like a list or a nested
 * record (order line items, a shipping address, extra product images) is stored as a JSON string
 * in a plain string field and parsed at the edges - a real, documented constraint of the
 * platform's Collections feature (see the reference web app's src/lib/json-field.ts), not a
 * workaround specific to this app.
 */
public final class JsonFields {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  private JsonFields() {}

  public static <T> T parse(String json, TypeReference<T> type, T fallback) {
    if (json == null || json.isBlank()) {
      return fallback;
    }
    try {
      return MAPPER.readValue(json, type);
    } catch (Exception e) {
      return fallback;
    }
  }

  public static List<String> parseStringList(String json) {
    return parse(json, new TypeReference<List<String>>() {}, List.of());
  }

  public static String stringify(Object value) {
    try {
      return MAPPER.writeValueAsString(value);
    } catch (Exception e) {
      throw new IllegalArgumentException("Could not serialize value to JSON", e);
    }
  }

  public static ObjectMapper mapper() {
    return MAPPER;
  }
}
