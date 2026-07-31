package dev.mudbase.showcase.ecommerce.domain;

import com.fasterxml.jackson.core.type.TypeReference;
import dev.mudbase.showcase.ecommerce.mudbase.DocumentMapper;
import dev.mudbase.showcase.ecommerce.mudbase.JsonFields;
import java.util.List;
import java.util.Map;

/** Mirrors the `carts` collection: one document per customer, upserted read-then-write. */
public class Cart {

  private final String id;
  private final String userId;
  private final List<CartItem> items;

  public Cart(String id, String userId, List<CartItem> items) {
    this.id = id;
    this.userId = userId;
    this.items = items;
  }

  public static Cart fromDocument(Map<String, Object> doc) {
    List<CartItem> items =
        JsonFields.parse(
            DocumentMapper.getString(doc, "itemsJson"), new TypeReference<List<CartItem>>() {}, List.of());
    return new Cart(DocumentMapper.getId(doc), DocumentMapper.getString(doc, "userId"), items);
  }

  public String getId() {
    return id;
  }

  public String getUserId() {
    return userId;
  }

  public List<CartItem> getItems() {
    return items;
  }

  public long getSubtotalCents() {
    return items.stream().mapToLong(CartItem::getLineTotalCents).sum();
  }

  public int getItemCount() {
    return items.stream().mapToInt(CartItem::quantity).sum();
  }

  public boolean isEmpty() {
    return items.isEmpty();
  }
}
