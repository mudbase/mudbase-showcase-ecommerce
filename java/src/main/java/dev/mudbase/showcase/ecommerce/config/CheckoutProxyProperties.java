package dev.mudbase.showcase.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * The already-deployed Next.js reference app's payment-link proxy. Creating a Mudbase Payment
 * Link requires a live org owner/admin bearer token (no API-key path); rather than every
 * per-language reimplementation of this storefront independently rotating that single-use
 * merchant refresh token (a real race condition if several run concurrently), checkout here
 * delegates the actual payment-link creation to that one deployed app's Route Handler.
 */
@ConfigurationProperties(prefix = "checkout")
public class CheckoutProxyProperties {

  private String proxyBaseUrl = "https://mudbase-showcase-ecommerce.vercel.app";

  public String getProxyBaseUrl() {
    return proxyBaseUrl;
  }

  public void setProxyBaseUrl(String proxyBaseUrl) {
    this.proxyBaseUrl = proxyBaseUrl.endsWith("/") ? proxyBaseUrl.substring(0, proxyBaseUrl.length() - 1) : proxyBaseUrl;
  }

  public String payLinkEndpoint() {
    return proxyBaseUrl + "/api/checkout/pay-link";
  }
}
