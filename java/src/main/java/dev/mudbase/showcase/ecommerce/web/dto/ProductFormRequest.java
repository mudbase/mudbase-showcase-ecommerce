package dev.mudbase.showcase.ecommerce.web.dto;

import dev.mudbase.showcase.ecommerce.domain.ProductInput;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * Gallery photos are entered one URL per line in a textarea rather than the reference app's
 * dynamic "Add photo" field array - a deliberate simplification for a server-rendered form with
 * no client JS field-array wiring; see README "Known limitations".
 */
public class ProductFormRequest {

  @NotBlank(message = "Name is required")
  private String name = "";

  private String description = "";

  @Min(value = 0, message = "Price can't be negative")
  private long priceCents;

  private Long compareAtPriceCents;

  @NotBlank private String currency = "USD";

  private String imageUrl = "";

  private String galleryUrlsText = "";

  private String category = "";

  @Min(value = 0, message = "Stock can't be negative")
  private int stock;

  private boolean active = true;

  @AssertTrue(message = "Compare-at price must be higher than the current price")
  public boolean isCompareAtPriceValid() {
    return compareAtPriceCents == null || compareAtPriceCents > priceCents;
  }

  public ProductInput toDomain(String slugOrNull) {
    return new ProductInput(
        name,
        description,
        priceCents,
        compareAtPriceCents,
        currency,
        imageUrl == null || imageUrl.isBlank() ? null : imageUrl,
        parseGalleryUrls(),
        category,
        stock,
        active,
        slugOrNull);
  }

  private List<String> parseGalleryUrls() {
    if (galleryUrlsText == null || galleryUrlsText.isBlank()) {
      return List.of();
    }
    return galleryUrlsText.lines().map(String::trim).filter(line -> !line.isEmpty()).toList();
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getDescription() {
    return description;
  }

  public void setDescription(String description) {
    this.description = description;
  }

  public long getPriceCents() {
    return priceCents;
  }

  public void setPriceCents(long priceCents) {
    this.priceCents = priceCents;
  }

  public Long getCompareAtPriceCents() {
    return compareAtPriceCents;
  }

  public void setCompareAtPriceCents(Long compareAtPriceCents) {
    this.compareAtPriceCents = compareAtPriceCents;
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

  public String getGalleryUrlsText() {
    return galleryUrlsText;
  }

  public void setGalleryUrlsText(String galleryUrlsText) {
    this.galleryUrlsText = galleryUrlsText;
  }

  public String getCategory() {
    return category;
  }

  public void setCategory(String category) {
    this.category = category;
  }

  public int getStock() {
    return stock;
  }

  public void setStock(int stock) {
    this.stock = stock;
  }

  public boolean isActive() {
    return active;
  }

  public void setActive(boolean active) {
    this.active = active;
  }
}
