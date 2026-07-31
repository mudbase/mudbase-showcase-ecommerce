package dev.mudbase.showcase.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** This app's own wiring: where it's hosted, and where the payment-link proxy lives. */
@ConfigurationProperties(prefix = "app")
public class AppProperties {

  /** This app's own public origin (no trailing slash), used to build the payment redirectUrl. */
  private String baseUrl = "http://localhost:8080";

  public String getBaseUrl() {
    return baseUrl;
  }

  public void setBaseUrl(String baseUrl) {
    this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
  }
}
