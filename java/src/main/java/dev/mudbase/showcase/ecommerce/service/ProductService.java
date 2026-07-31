package dev.mudbase.showcase.ecommerce.service;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.config.MudbaseProperties;
import dev.mudbase.showcase.ecommerce.domain.Product;
import dev.mudbase.showcase.ecommerce.domain.ProductInput;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.ecommerce.support.Formatting;
import jakarta.servlet.http.HttpSession;
import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeSet;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `products` collection. Catalog browsing needs "some" Mudbase-issued
 * bearer token to satisfy the collection's "authenticated role, read-only" permission even before
 * sign-in - {@link SessionAuthService#publicReadToken} supplies that (the signed-in user's own
 * token, or a lazily-created anonymous guest token). Seller writes always use the seller's own
 * JWT, which the `seller` role grants unconditional CRUD on this collection.
 */
@Service
public class ProductService {

  private static final int CATALOG_PAGE_SIZE = 60;
  private static final int SELLER_PAGE_SIZE = 100;
  private static final String SLUG_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";
  private static final SecureRandom RANDOM = new SecureRandom();

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final SessionAuthService sessionAuthService;

  public ProductService(MudbaseDataClient dataClient, MudbaseProperties properties, SessionAuthService sessionAuthService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.sessionAuthService = sessionAuthService;
  }

  public List<Product> listActive(HttpSession session, String category) {
    String token = sessionAuthService.publicReadToken(session);
    Map<String, Object> filter =
        (category == null || category.isBlank())
            ? Map.of("isActive", true)
            : Map.of("isActive", true, "category", category);
    return dataClient
        .list(token, properties.getProductsCollectionId(), filter, "-createdAt", 1, CATALOG_PAGE_SIZE)
        .stream()
        .map(Product::fromDocument)
        .toList();
  }

  public List<String> distinctCategories(List<Product> products) {
    TreeSet<String> categories = new TreeSet<>();
    for (Product product : products) {
      if (product.getCategory() != null && !product.getCategory().isBlank()) {
        categories.add(product.getCategory());
      }
    }
    return List.copyOf(categories);
  }

  public Optional<Product> findActiveBySlug(HttpSession session, String slug) {
    String token = sessionAuthService.publicReadToken(session);
    List<Map<String, Object>> docs =
        dataClient.list(token, properties.getProductsCollectionId(), Map.of("slug", slug), "-createdAt", 1, 1);
    return docs.isEmpty() ? Optional.empty() : Optional.of(Product.fromDocument(docs.get(0)));
  }

  public List<Product> listAllForSeller(AuthSession seller) {
    return dataClient
        .list(seller.getToken(), properties.getProductsCollectionId(), Map.of(), "-createdAt", 1, SELLER_PAGE_SIZE)
        .stream()
        .map(Product::fromDocument)
        .toList();
  }

  public Optional<Product> findByIdForSeller(AuthSession seller, String id) {
    try {
      return Optional.of(Product.fromDocument(dataClient.get(seller.getToken(), properties.getProductsCollectionId(), id)));
    } catch (RuntimeException e) {
      return Optional.empty();
    }
  }

  public Product create(AuthSession seller, ProductInput input) {
    String slug = Formatting.slugify(input.name()) + "-" + randomSuffix();
    ProductInput withSlug =
        new ProductInput(
            input.name(),
            input.description(),
            input.priceCents(),
            input.compareAtPriceCents(),
            input.currency(),
            input.imageUrl(),
            input.galleryUrls(),
            input.category(),
            input.stock(),
            input.isActive(),
            slug);
    Map<String, Object> body = new LinkedHashMap<>(Product.toCreateBody(withSlug, seller.getUserId()));
    return Product.fromDocument(dataClient.create(seller.getToken(), properties.getProductsCollectionId(), body));
  }

  public Product update(AuthSession seller, String id, ProductInput input) {
    Map<String, Object> body = Product.toUpdateBody(input);
    return Product.fromDocument(dataClient.update(seller.getToken(), properties.getProductsCollectionId(), id, body));
  }

  public void delete(AuthSession seller, String id) {
    dataClient.delete(seller.getToken(), properties.getProductsCollectionId(), id);
  }

  private static String randomSuffix() {
    StringBuilder sb = new StringBuilder(6);
    for (int i = 0; i < 6; i++) {
      sb.append(SLUG_ALPHABET.charAt(RANDOM.nextInt(SLUG_ALPHABET.length())));
    }
    return sb.toString();
  }
}
