package dev.mudbase.showcase.ecommerce.domain;

import dev.mudbase.showcase.ecommerce.support.Formatting;
import java.io.Serializable;

/**
 * One line in a cart or in an order's itemsJson snapshot at checkout time. Implements {@link
 * Serializable} because the guest (pre-login) cart lives as a plain HttpSession attribute - see
 * {@code auth.GuestCartHolder}.
 */
public record CartItem(String productId, String name, long priceCents, String currency, String imageUrl, int quantity)
    implements Serializable {

  public CartItem withQuantity(int newQuantity) {
    return new CartItem(productId, name, priceCents, currency, imageUrl, newQuantity);
  }

  public long getLineTotalCents() {
    return priceCents * quantity;
  }

  public String getFormattedUnitPrice() {
    return Formatting.formatMoney(priceCents, currency);
  }

  public String getFormattedLineTotal() {
    return Formatting.formatMoney(getLineTotalCents(), currency);
  }
}
