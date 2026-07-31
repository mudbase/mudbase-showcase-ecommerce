package dev.mudbase.showcase.ecommerce.config;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Every ID this app needs to talk to a provisioned Mudbase project. See java/.env.example for the
 * full list and where each value comes from.
 */
@ConfigurationProperties(prefix = "mudbase")
public class MudbaseProperties {

  private String baseUrl;
  private String projectId;
  private String productsCollectionId;
  private String ordersCollectionId;
  private String cartsCollectionId;

  @PostConstruct
  void validate() {
    requireNonBlank(projectId, "mudbase.project-id (MUDBASE_PROJECT_ID)");
    requireNonBlank(productsCollectionId, "mudbase.products-collection-id (MUDBASE_PRODUCTS_COLLECTION_ID)");
    requireNonBlank(ordersCollectionId, "mudbase.orders-collection-id (MUDBASE_ORDERS_COLLECTION_ID)");
    requireNonBlank(cartsCollectionId, "mudbase.carts-collection-id (MUDBASE_CARTS_COLLECTION_ID)");
  }

  private static void requireNonBlank(String value, String name) {
    if (value == null || value.isBlank()) {
      throw new IllegalStateException("Missing required configuration value: " + name);
    }
  }

  public String getBaseUrl() {
    return baseUrl;
  }

  public void setBaseUrl(String baseUrl) {
    this.baseUrl = baseUrl;
  }

  public String getProjectId() {
    return projectId;
  }

  public void setProjectId(String projectId) {
    this.projectId = projectId;
  }

  public String getProductsCollectionId() {
    return productsCollectionId;
  }

  public void setProductsCollectionId(String productsCollectionId) {
    this.productsCollectionId = productsCollectionId;
  }

  public String getOrdersCollectionId() {
    return ordersCollectionId;
  }

  public void setOrdersCollectionId(String ordersCollectionId) {
    this.ordersCollectionId = ordersCollectionId;
  }

  public String getCartsCollectionId() {
    return cartsCollectionId;
  }

  public void setCartsCollectionId(String cartsCollectionId) {
    this.cartsCollectionId = cartsCollectionId;
  }
}
