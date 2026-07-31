package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.domain.Product;
import dev.mudbase.showcase.ecommerce.service.ProductService;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@Controller
public class ProductController {

  private final ProductService productService;
  private final ViewModelHelper viewModelHelper;

  public ProductController(ProductService productService, ViewModelHelper viewModelHelper) {
    this.productService = productService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/products/{slug}")
  public String detail(@PathVariable String slug, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    Optional<Product> product = productService.findActiveBySlug(session, slug);
    if (product.isEmpty()) {
      model.addAttribute("errorMessage", "This product isn't available anymore.");
      return "products/not-found";
    }
    model.addAttribute("product", product.get());
    return "products/detail";
  }
}
