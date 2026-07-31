package dev.mudbase.showcase.ecommerce.domain;

import java.util.List;

public record ShippingAddress(
    String fullName, String line1, String line2, String city, String region, String postalCode, String country) {

  /** Display-ready lines for the order detail page - fullName / street / city,region postal / country. */
  public List<String> getDisplayLines() {
    String street = line2 == null || line2.isBlank() ? line1 : line1 + ", " + line2;
    return List.of(fullName, street, city + ", " + region + " " + postalCode, country);
  }
}
