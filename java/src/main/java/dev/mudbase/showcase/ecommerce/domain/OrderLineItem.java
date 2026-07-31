package dev.mudbase.showcase.ecommerce.domain;

import dev.mudbase.showcase.ecommerce.support.Formatting;

/** A snapshot of one cart line as recorded on the order at checkout time (order.currency applies). */
public record OrderLineItem(String productId, String name, long priceCents, int quantity) {

  public long getLineTotalCents() {
    return priceCents * quantity;
  }

  public String getFormattedUnitPrice(String currency) {
    return Formatting.formatMoney(priceCents, currency);
  }

  public String getFormattedLineTotal(String currency) {
    return Formatting.formatMoney(getLineTotalCents(), currency);
  }
}
