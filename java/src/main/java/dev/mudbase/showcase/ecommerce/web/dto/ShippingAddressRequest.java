package dev.mudbase.showcase.ecommerce.web.dto;

import dev.mudbase.showcase.ecommerce.domain.ShippingAddress;
import jakarta.validation.constraints.NotBlank;

public class ShippingAddressRequest {

  @NotBlank(message = "Full name is required")
  private String fullName = "";

  @NotBlank(message = "Address is required")
  private String line1 = "";

  private String line2 = "";

  @NotBlank(message = "City is required")
  private String city = "";

  @NotBlank(message = "State/region is required")
  private String region = "";

  @NotBlank(message = "Postal code is required")
  private String postalCode = "";

  @NotBlank(message = "Country is required")
  private String country = "";

  public ShippingAddress toDomain() {
    return new ShippingAddress(fullName, line1, line2, city, region, postalCode, country);
  }

  public String getFullName() {
    return fullName;
  }

  public void setFullName(String fullName) {
    this.fullName = fullName;
  }

  public String getLine1() {
    return line1;
  }

  public void setLine1(String line1) {
    this.line1 = line1;
  }

  public String getLine2() {
    return line2;
  }

  public void setLine2(String line2) {
    this.line2 = line2;
  }

  public String getCity() {
    return city;
  }

  public void setCity(String city) {
    this.city = city;
  }

  public String getRegion() {
    return region;
  }

  public void setRegion(String region) {
    this.region = region;
  }

  public String getPostalCode() {
    return postalCode;
  }

  public void setPostalCode(String postalCode) {
    this.postalCode = postalCode;
  }

  public String getCountry() {
    return country;
  }

  public void setCountry(String country) {
    this.country = country;
  }
}
