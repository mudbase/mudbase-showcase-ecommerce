package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.domain.Product;
import dev.mudbase.showcase.ecommerce.service.ProductService;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import dev.mudbase.showcase.ecommerce.web.dto.ProductFormRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;

/** Gated by RequireSellerInterceptor on "/seller/**". */
@Controller
public class SellerProductController {

  private final ProductService productService;
  private final SessionAuthService sessionAuthService;
  private final ViewModelHelper viewModelHelper;

  public SellerProductController(ProductService productService, SessionAuthService sessionAuthService, ViewModelHelper viewModelHelper) {
    this.productService = productService;
    this.sessionAuthService = sessionAuthService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/seller/products/new")
  public String newForm(Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    if (!model.containsAttribute("productForm")) {
      model.addAttribute("productForm", new ProductFormRequest());
    }
    model.addAttribute("isEdit", false);
    return "seller/product-form";
  }

  @PostMapping("/seller/products")
  public String create(
      @Valid @ModelAttribute("productForm") ProductFormRequest form, BindingResult bindingResult, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    if (bindingResult.hasErrors()) {
      model.addAttribute("isEdit", false);
      return "seller/product-form";
    }
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    productService.create(seller, form.toDomain(null));
    return "redirect:/seller";
  }

  @GetMapping("/seller/products/{id}/edit")
  public String editForm(@PathVariable String id, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    Optional<Product> product = productService.findByIdForSeller(seller, id);
    if (product.isEmpty()) {
      model.addAttribute("errorMessage", "This product couldn't be found.");
      return "products/not-found";
    }
    model.addAttribute("productForm", toForm(product.get()));
    model.addAttribute("isEdit", true);
    model.addAttribute("productId", id);
    return "seller/product-form";
  }

  @PostMapping("/seller/products/{id}")
  public String update(
      @PathVariable String id,
      @Valid @ModelAttribute("productForm") ProductFormRequest form,
      BindingResult bindingResult,
      Model model,
      HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    if (bindingResult.hasErrors()) {
      model.addAttribute("isEdit", true);
      model.addAttribute("productId", id);
      return "seller/product-form";
    }
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    productService.update(seller, id, form.toDomain(null));
    return "redirect:/seller";
  }

  @PostMapping("/seller/products/{id}/delete")
  public String delete(@PathVariable String id, HttpSession session) {
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    productService.delete(seller, id);
    return "redirect:/seller";
  }

  private ProductFormRequest toForm(Product product) {
    ProductFormRequest form = new ProductFormRequest();
    form.setName(product.getName());
    form.setDescription(product.getDescription() != null ? product.getDescription() : "");
    form.setPriceCents(product.getPriceCents());
    form.setCompareAtPriceCents(product.getCompareAtPriceCents());
    form.setCurrency(product.getCurrency());
    form.setImageUrl(product.getImageUrl() != null ? product.getImageUrl() : "");
    form.setGalleryUrlsText(String.join("\n", product.getGallery()));
    form.setCategory(product.getCategory() != null ? product.getCategory() : "");
    form.setStock(product.getStock());
    form.setActive(product.isActive());
    return form;
  }
}
