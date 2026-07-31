package dev.mudbase.showcase.ecommerce.mudbase;

import dev.mudbase.sdk.model.DataListResponseDataInner;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Converts the SDK's document shapes into a plain {@code Map<String, Object>} keyed the same way
 * as the raw Mudbase JSON ({@code _id}, {@code createdAt}, {@code updatedAt}, plus every
 * collection-defined field), and provides defensive readers for pulling typed values back out.
 *
 * <p>Two document shapes come out of the generated SDK and need reconciling: {@link
 * DataListResponseDataInner} (used by {@code listData}) types {@code _id}/{@code createdAt}/
 * {@code updatedAt} explicitly and puts every other collection field in an {@code
 * additionalProperties} map, while {@code DataResponse.getData()} (used by {@code
 * getData}/{@code createData}/{@code updateData}) is declared as a raw {@code Object} that Gson
 * deserializes into a {@code LinkedTreeMap<String,Object>} with every field - including {@code
 * _id} - flattened together already. Both are normalized here into the same {@code Map} shape so
 * the domain mappers (Product/Order/Cart) never need to care which SDK call produced the data.
 */
public final class DocumentMapper {

  private DocumentMapper() {}

  public static Map<String, Object> fromListItem(DataListResponseDataInner item) {
    Map<String, Object> map = new LinkedHashMap<>();
    map.put("_id", item.getId());
    map.put("createdAt", item.getCreatedAt() != null ? item.getCreatedAt().toString() : null);
    map.put("updatedAt", item.getUpdatedAt() != null ? item.getUpdatedAt().toString() : null);
    if (item.getAdditionalProperties() != null) {
      map.putAll(item.getAdditionalProperties());
    }
    return map;
  }

  /**
   * {@code DataResponse.getData()} / {@code DataListResponse}'s raw entries deserialize (via
   * Gson, since the declared type is {@code Object}) into a {@code LinkedTreeMap<String,Object>}
   * for any JSON object - safe to treat as a plain {@code Map} here.
   */
  @SuppressWarnings("unchecked")
  public static Map<String, Object> asMap(Object data) {
    if (data == null) {
      return Map.of();
    }
    if (data instanceof Map) {
      return (Map<String, Object>) data;
    }
    throw new IllegalStateException("Expected a JSON object, got: " + data.getClass());
  }

  public static String getId(Map<String, Object> doc) {
    return getString(doc, "_id");
  }

  public static String getString(Map<String, Object> doc, String key) {
    Object value = doc.get(key);
    return value != null ? value.toString() : null;
  }

  public static String getString(Map<String, Object> doc, String key, String fallback) {
    String value = getString(doc, key);
    return value != null ? value : fallback;
  }

  public static long getLong(Map<String, Object> doc, String key, long fallback) {
    Object value = doc.get(key);
    if (value instanceof Number number) {
      return number.longValue();
    }
    if (value instanceof String s && !s.isBlank()) {
      try {
        return Long.parseLong(s);
      } catch (NumberFormatException ignored) {
        return fallback;
      }
    }
    return fallback;
  }

  public static Long getNullableLong(Map<String, Object> doc, String key) {
    Object value = doc.get(key);
    if (value instanceof Number number) {
      return number.longValue();
    }
    return null;
  }

  public static int getInt(Map<String, Object> doc, String key, int fallback) {
    return (int) getLong(doc, key, fallback);
  }

  public static boolean getBoolean(Map<String, Object> doc, String key, boolean fallback) {
    Object value = doc.get(key);
    if (value instanceof Boolean bool) {
      return bool;
    }
    if (value instanceof String s) {
      return Boolean.parseBoolean(s);
    }
    return fallback;
  }
}
