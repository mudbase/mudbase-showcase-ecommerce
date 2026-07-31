package dev.mudbase.showcase.ecommerce.mudbase;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;

/**
 * Mudbase collection fields have a fixed type enum (string, number, boolean, date, email, url,
 * enum, reference) with no native array/object type. Anything shaped like a list or a nested
 * record (order line items, a shipping address, extra product images) is stored as a JSON string
 * in a plain string field and parsed at the edges - a real, documented constraint of the
 * platform's Collections feature (see the reference web app's src/lib/json-field.ts), not a
 * workaround specific to this app.
 *
 * <p><b>Why unknown properties are disabled here.</b> {@link #stringify} serializes domain
 * records like {@code CartItem} and {@code OrderLineItem} with Jackson's default bean
 * introspection, which picks up every no-arg {@code get*()} method - not just the record's
 * canonical accessors - so derived getters like {@code CartItem.getLineTotalCents()} or
 * {@code getFormattedUnitPrice()} end up written into the stored JSON alongside the real fields.
 * Reading that same JSON back with Jackson's strict default (fail on any property the target
 * type doesn't declare as a constructor parameter) then throws on every single cart or order this
 * app ever writes - confirmed live: a cart added via {@code CartService} persisted correctly to
 * Mudbase but always rendered as empty, because {@link #parse} caught the resulting exception and
 * fell back to the caller's empty default. Disabling {@code FAIL_ON_UNKNOWN_PROPERTIES} makes the
 * round trip tolerant of those derived fields without having to hand-write a `@JsonIgnore` on
 * every computed getter this app's domain records may ever add.
 */
public final class JsonFields {

  private static final ObjectMapper MAPPER =
      new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

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
