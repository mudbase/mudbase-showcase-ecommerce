package dev.mudbase.showcase.ecommerce;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Commonwealth Goods - a storefront served entirely by Mudbase (cloud.mudbase.dev): auth,
 * collections, and payment links. This Spring Boot + Thymeleaf app is the Java reimplementation
 * of the reference Next.js storefront at ../web - same business rules, same Mudbase project
 * shape, same "no custom backend other than the payment-link proxy" constraint.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class EcommerceApplication {

  public static void main(String[] args) {
    SpringApplication.run(EcommerceApplication.class, args);
  }
}
