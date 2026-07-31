package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.domain.CartItem;
import dev.mudbase.showcase.ecommerce.service.CartService;
import dev.mudbase.showcase.ecommerce.support.Formatting;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import dev.mudbase.showcase.ecommerce.web.dto.AddToCartRequest;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class CartController {

  private final CartService cartService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public CartController(CartService cartService, ViewModelHelper viewModelHelper, SessionAuthService sessionAuthService) {
    this.cartService = cartService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @GetMapping("/cart")
  public String view(Model model, HttpSession session) {
    AuthSession auth = viewModelHelper.addLayoutAttributes(model, session);
    List<CartItem> items = cartService.getItems(session, auth);
    long subtotalCents = cartService.getSubtotalCents(items);
    String currency = items.isEmpty() ? "USD" : items.get(0).currency();
    model.addAttribute("items", items);
    model.addAttribute("subtotalCents", subtotalCents);
    model.addAttribute("currency", currency);
    model.addAttribute("formattedSubtotal", Formatting.formatMoney(subtotalCents, currency));
    return "cart/view";
  }

  @PostMapping("/cart/add")
  public String add(AddToCartRequest form, HttpSession session, @RequestParam(value = "redirect", required = false) String redirect) {
    AuthSession auth = currentAuthOrNull(session);
    cartService.addItem(session, auth, form.toCartItem(), form.getQuantity());
    return "redirect:" + (redirect != null && !redirect.isBlank() ? redirect : "/cart");
  }

  @PostMapping("/cart/update")
  public String update(
      @RequestParam("productId") String productId, @RequestParam("quantity") int quantity, HttpSession session) {
    cartService.updateQuantity(session, currentAuthOrNull(session), productId, quantity);
    return "redirect:/cart";
  }

  @PostMapping("/cart/remove")
  public String remove(@RequestParam("productId") String productId, HttpSession session) {
    cartService.removeItem(session, currentAuthOrNull(session), productId);
    return "redirect:/cart";
  }

  private AuthSession currentAuthOrNull(HttpSession session) {
    return sessionAuthService.signedInUser(session).orElse(null);
  }
}
