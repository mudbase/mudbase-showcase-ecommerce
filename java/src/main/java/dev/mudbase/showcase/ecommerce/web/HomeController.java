package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.domain.Product;
import dev.mudbase.showcase.ecommerce.service.ProductService;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class HomeController {

  private final ProductService productService;
  private final ViewModelHelper viewModelHelper;

  public HomeController(ProductService productService, ViewModelHelper viewModelHelper) {
    this.productService = productService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/")
  public String catalog(
      @RequestParam(value = "category", required = false) String category, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);

    // Categories are derived from the unfiltered catalog so the filter bar doesn't shrink to
    // just the active selection once a category is chosen.
    List<Product> allActive = productService.listActive(session, null);
    List<Product> visible =
        (category == null || category.isBlank())
            ? allActive
            : allActive.stream().filter(p -> category.equals(p.getCategory())).toList();

    model.addAttribute("products", visible);
    model.addAttribute("categories", productService.distinctCategories(allActive));
    model.addAttribute("selectedCategory", category);
    return "index";
  }
}
