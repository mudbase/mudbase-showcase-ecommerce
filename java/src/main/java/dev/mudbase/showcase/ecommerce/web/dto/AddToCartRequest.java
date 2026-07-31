package dev.mudbase.showcase.ecommerce.web.dto;

import dev.mudbase.showcase.ecommerce.domain.CartItem;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/** Bound from hidden fields on the product detail page's "Add to cart" form. */
public class AddToCartRequest {

  @NotBlank private String productId = "";

  @NotBlank private String name = "";

  private long priceCents;

  private String currency = "USD";

  private String imageUrl;

  @Min(1)
  private int quantity = 1;

  public CartItem toCartItem() {
    return new CartItem(productId, name, priceCents, currency, imageUrl, quantity);
  }

  public String getProductId() {
    return productId;
  }

  public void setProductId(String productId) {
    this.productId = productId;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public long getPriceCents() {
    return priceCents;
  }

  public void setPriceCents(long priceCents) {
    this.priceCents = priceCents;
  }

  public String getCurrency() {
    return currency;
  }

  public void setCurrency(String currency) {
    this.currency = currency;
  }

  public String getImageUrl() {
    return imageUrl;
  }

  public void setImageUrl(String imageUrl) {
    this.imageUrl = imageUrl;
  }

  public int getQuantity() {
    return quantity;
  }

  public void setQuantity(int quantity) {
    this.quantity = quantity;
  }
}
