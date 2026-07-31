package dev.mudbase.showcase.ecommerce.support;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.domain.CartItem;
import dev.mudbase.showcase.ecommerce.service.CartService;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Component;
import org.springframework.ui.Model;

/**
 * Populates the header/nav attributes every Thymeleaf page needs (current user, cart badge
 * count). Deliberately called explicitly per template-rendering controller method rather than
 * wired as a global {@code @ControllerAdvice @ModelAttribute} - a handful of endpoints in this
 * app return JSON (the payment-link status poll) and must not pay for a cart lookup on every
 * request just to populate a Model nobody reads.
 */
@Component
public class ViewModelHelper {

  private final SessionAuthService sessionAuthService;
  private final CartService cartService;

  public ViewModelHelper(SessionAuthService sessionAuthService, CartService cartService) {
    this.sessionAuthService = sessionAuthService;
    this.cartService = cartService;
  }

  public AuthSession addLayoutAttributes(Model model, HttpSession session) {
    AuthSession auth = sessionAuthService.current(session).filter(AuthSession::isSignedIn).orElse(null);
    List<CartItem> items = cartService.getItems(session, auth);
    int cartItemCount = items.stream().mapToInt(CartItem::quantity).sum();

    model.addAttribute("currentUser", auth);
    model.addAttribute("isSignedIn", auth != null);
    model.addAttribute("isSeller", auth != null && auth.isSeller());
    model.addAttribute("cartItemCount", cartItemCount);
    return auth;
  }
}
