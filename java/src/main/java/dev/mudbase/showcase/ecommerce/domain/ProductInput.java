package dev.mudbase.showcase.ecommerce.domain;

import java.util.List;

/** Validated seller-submitted product fields, decoupled from the web form-binding bean. */
public record ProductInput(
    String name,
    String description,
    long priceCents,
    Long compareAtPriceCents,
    String currency,
    String imageUrl,
    List<String> galleryUrls,
    String category,
    int stock,
    boolean active,
    String slug) {

  public boolean isActive() {
    return active;
  }
}
