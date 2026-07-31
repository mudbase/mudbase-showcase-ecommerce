package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.domain.Order;
import dev.mudbase.showcase.ecommerce.service.OrderService;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/** Gated by RequireSignInInterceptor on "/orders/**" - a real account is required either way. */
@Controller
public class OrderController {

  private final OrderService orderService;
  private final SessionAuthService sessionAuthService;
  private final ViewModelHelper viewModelHelper;

  public OrderController(OrderService orderService, SessionAuthService sessionAuthService, ViewModelHelper viewModelHelper) {
    this.orderService = orderService;
    this.sessionAuthService = sessionAuthService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/orders")
  public String list(Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession auth = sessionAuthService.signedInUser(session).orElseThrow();
    model.addAttribute("orders", orderService.listForCustomer(auth));
    return "orders/list";
  }

  @GetMapping("/orders/{id}")
  public String detail(@PathVariable String id, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession auth = sessionAuthService.signedInUser(session).orElseThrow();
    Optional<Order> order = orderService.findById(auth, id);
    if (order.isEmpty()) {
      model.addAttribute("errorMessage", "This order couldn't be found.");
      return "orders/not-found";
    }
    model.addAttribute("order", order.get());
    return "orders/detail";
  }
}
