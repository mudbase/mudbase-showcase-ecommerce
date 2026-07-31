package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.domain.Order;
import dev.mudbase.showcase.ecommerce.domain.OrderStatus;
import dev.mudbase.showcase.ecommerce.service.OrderService;
import dev.mudbase.showcase.ecommerce.service.ProductService;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;

/** Gated by RequireSellerInterceptor on "/seller/**" - see that class for the guard's scope. */
@Controller
public class SellerController {

  private final OrderService orderService;
  private final ProductService productService;
  private final SessionAuthService sessionAuthService;
  private final ViewModelHelper viewModelHelper;

  public SellerController(
      OrderService orderService, ProductService productService, SessionAuthService sessionAuthService, ViewModelHelper viewModelHelper) {
    this.orderService = orderService;
    this.productService = productService;
    this.sessionAuthService = sessionAuthService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/seller")
  public String dashboard(Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    model.addAttribute("orders", orderService.listAllForSeller(seller));
    model.addAttribute("products", productService.listAllForSeller(seller));
    return "seller/dashboard";
  }

  @PostMapping("/seller/orders/{id}/advance")
  public String advanceOrder(@PathVariable String id, HttpSession session) {
    AuthSession seller = sessionAuthService.signedInUser(session).orElseThrow();
    Optional<Order> order = orderService.findById(seller, id);
    if (order.isPresent()) {
      OrderStatus next = order.get().getOrderStatus().getNextFulfillmentStatus();
      if (next != null) {
        orderService.updateStatus(seller, id, next);
      }
    }
    return "redirect:/seller";
  }
}
