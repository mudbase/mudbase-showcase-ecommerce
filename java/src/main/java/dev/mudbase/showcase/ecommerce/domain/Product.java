package dev.mudbase.showcase.ecommerce.domain;

import dev.mudbase.showcase.ecommerce.mudbase.DocumentMapper;
import dev.mudbase.showcase.ecommerce.mudbase.JsonFields;
import dev.mudbase.showcase.ecommerce.support.Formatting;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Mirrors the `products` collection - see plan/build-plan.md in the reference web app. */
public class Product {

  private final String id;
  private final String name;
  private final String slug;
  private final String description;
  private final long priceCents;
  private final Long compareAtPriceCents;
  private final String currency;
  private final String imageUrl;
  private final List<String> gallery;
  private final String category;
  private final int stock;
  private final boolean active;
  private final String sellerId;
  private final String createdAt;

  public Product(
      String id,
      String name,
      String slug,
      String description,
      long priceCents,
      Long compareAtPriceCents,
      String currency,
      String imageUrl,
      List<String> gallery,
      String category,
      int stock,
      boolean active,
      String sellerId,
      String createdAt) {
    this.id = id;
    this.name = name;
    this.slug = slug;
    this.description = description;
    this.priceCents = priceCents;
    this.compareAtPriceCents = compareAtPriceCents;
    this.currency = currency;
    this.imageUrl = imageUrl;
    this.gallery = gallery;
    this.category = category;
    this.stock = stock;
    this.active = active;
    this.sellerId = sellerId;
    this.createdAt = createdAt;
  }

  public static Product fromDocument(Map<String, Object> doc) {
    return new Product(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "name"),
        DocumentMapper.getString(doc, "slug"),
        DocumentMapper.getString(doc, "description"),
        DocumentMapper.getLong(doc, "priceCents", 0),
        DocumentMapper.getNullableLong(doc, "compareAtPriceCents"),
        DocumentMapper.getString(doc, "currency", "USD"),
        DocumentMapper.getString(doc, "imageUrl"),
        JsonFields.parseStringList(DocumentMapper.getString(doc, "galleryJson")),
        DocumentMapper.getString(doc, "category"),
        DocumentMapper.getInt(doc, "stock", 0),
        DocumentMapper.getBoolean(doc, "isActive", true),
        DocumentMapper.getString(doc, "sellerId"),
        DocumentMapper.getString(doc, "createdAt"));
  }

  /** All photos in display order: main image first, then the gallery, with blanks dropped. */
  public List<String> getImages() {
    List<String> images = new ArrayList<>();
    if (imageUrl != null && !imageUrl.isBlank()) {
      images.add(imageUrl);
    }
    for (String url : gallery) {
      if (url != null && !url.isBlank()) {
        images.add(url);
      }
    }
    return images;
  }

  public String getId() {
    return id;
  }

  public String getName() {
    return name;
  }

  public String getSlug() {
    return slug;
  }

  public String getDescription() {
    return description;
  }

  public long getPriceCents() {
    return priceCents;
  }

  public Long getCompareAtPriceCents() {
    return compareAtPriceCents;
  }

  public String getCurrency() {
    return currency;
  }

  public String getImageUrl() {
    return imageUrl;
  }

  public List<String> getGallery() {
    return gallery;
  }

  public String getCategory() {
    return category;
  }

  public String getCategoryOrDefault() {
    return category == null || category.isBlank() ? "General" : category;
  }

  public int getStock() {
    return stock;
  }

  public boolean isActive() {
    return active;
  }

  public boolean isOutOfStock() {
    return stock <= 0;
  }

  public String getSellerId() {
    return sellerId;
  }

  public String getCreatedAt() {
    return createdAt;
  }

  public String getFormattedPrice() {
    return Formatting.formatMoney(priceCents, currency);
  }

  public String getFormattedCompareAtPrice() {
    return compareAtPriceCents != null ? Formatting.formatMoney(compareAtPriceCents, currency) : null;
  }

  public Integer getDiscountPercent() {
    return Formatting.discountPercent(priceCents, compareAtPriceCents);
  }

  public boolean hasDiscount() {
    return getDiscountPercent() != null;
  }

  /** A new, unsaved product ready for {@code createDocument} - see ProductService. */
  public static Map<String, Object> toCreateBody(ProductInput input, String sellerId) {
    Map<String, Object> body = new LinkedHashMap<>(toUpdateBody(input));
    body.put("slug", input.slug());
    body.put("sellerId", sellerId);
    return body;
  }

  /** Fields writable on an existing product via {@code updateDocument}. */
  public static Map<String, Object> toUpdateBody(ProductInput input) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("name", input.name());
    body.put("description", input.description());
    body.put("priceCents", input.priceCents());
    if (input.compareAtPriceCents() != null) {
      body.put("compareAtPriceCents", input.compareAtPriceCents());
    }
    body.put("currency", input.currency());
    body.put("imageUrl", input.imageUrl());
    body.put("galleryJson", JsonFields.stringify(input.galleryUrls()));
    body.put("category", input.category());
    body.put("stock", input.stock());
    body.put("isActive", input.isActive());
    return body;
  }
}
