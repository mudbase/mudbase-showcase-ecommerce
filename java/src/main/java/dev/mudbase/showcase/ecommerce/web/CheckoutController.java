package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.config.AppProperties;
import dev.mudbase.showcase.ecommerce.domain.CartItem;
import dev.mudbase.showcase.ecommerce.domain.Order;
import dev.mudbase.showcase.ecommerce.domain.PaymentLink;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseApiException;
import dev.mudbase.showcase.ecommerce.service.AuthService;
import dev.mudbase.showcase.ecommerce.service.CartService;
import dev.mudbase.showcase.ecommerce.service.OrderService;
import dev.mudbase.showcase.ecommerce.service.PaymentLinkCreationResult;
import dev.mudbase.showcase.ecommerce.service.PaymentLinkService;
import dev.mudbase.showcase.ecommerce.support.Formatting;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import dev.mudbase.showcase.ecommerce.web.dto.LoginRequest;
import dev.mudbase.showcase.ecommerce.web.dto.RegisterRequest;
import dev.mudbase.showcase.ecommerce.web.dto.ShippingAddressRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Checkout mirrors the reference app's flow: submit shipping -> create an `orders` document as
 * the signed-in customer -> ask the deployed proxy app for a Payment Link -> poll its public
 * status until paid or expired. A guest reaching checkout sees inline sign-in/register forms
 * (posting back to this same page) instead of being redirected away, exactly like the reference
 * app's embedded LoginForm/RegisterForm.
 */
@Controller
@RequestMapping("/checkout")
public class CheckoutController {

  private final CartService cartService;
  private final OrderService orderService;
  private final PaymentLinkService paymentLinkService;
  private final AuthService authService;
  private final SessionAuthService sessionAuthService;
  private final ViewModelHelper viewModelHelper;
  private final AppProperties appProperties;

  public CheckoutController(
      CartService cartService,
      OrderService orderService,
      PaymentLinkService paymentLinkService,
      AuthService authService,
      SessionAuthService sessionAuthService,
      ViewModelHelper viewModelHelper,
      AppProperties appProperties) {
    this.cartService = cartService;
    this.orderService = orderService;
    this.paymentLinkService = paymentLinkService;
    this.authService = authService;
    this.sessionAuthService = sessionAuthService;
    this.viewModelHelper = viewModelHelper;
    this.appProperties = appProperties;
  }

  @GetMapping
  public String start(Model model, HttpSession session) {
    AuthSession auth = viewModelHelper.addLayoutAttributes(model, session);
    populateCheckoutModel(model, session, auth);
    if (!model.containsAttribute("loginRequest")) {
      model.addAttribute("loginRequest", new LoginRequest());
    }
    if (!model.containsAttribute("registerRequest")) {
      model.addAttribute("registerRequest", new RegisterRequest());
    }
    if (!model.containsAttribute("shippingAddressRequest")) {
      model.addAttribute("shippingAddressRequest", new ShippingAddressRequest());
    }
    return "checkout/start";
  }

  @PostMapping("/login")
  public String inlineLogin(
      @Valid @ModelAttribute("loginRequest") LoginRequest form, BindingResult bindingResult, Model model, HttpSession session) {
    AuthSession auth = viewModelHelper.addLayoutAttributes(model, session);
    if (!bindingResult.hasErrors()) {
      try {
        authService.login(session, form.getEmail(), form.getPassword());
        return "redirect:/checkout";
      } catch (MudbaseApiException e) {
        model.addAttribute("authError", e.getMessage());
      }
    }
    populateCheckoutModel(model, session, sessionAuthService.current(session).orElse(auth));
    model.addAttribute("registerRequest", new RegisterRequest());
    return "checkout/start";
  }

  @PostMapping("/register")
  public String inlineRegister(
      @Valid @ModelAttribute("registerRequest") RegisterRequest form, BindingResult bindingResult, Model model, HttpSession session) {
    AuthSession auth = viewModelHelper.addLayoutAttributes(model, session);
    if (!bindingResult.hasErrors()) {
      try {
        authService.registerCustomer(
            session, form.getEmail(), form.getPassword(), form.getFirstName(), form.getLastName(), form.isAgreedToTerms());
        return "redirect:/checkout";
      } catch (MudbaseApiException e) {
        model.addAttribute("authError", e.getMessage());
      }
    }
    populateCheckoutModel(model, session, sessionAuthService.current(session).orElse(auth));
    model.addAttribute("loginRequest", new LoginRequest());
    return "checkout/start";
  }

  @PostMapping
  public String placeOrder(
      @Valid @ModelAttribute("shippingAddressRequest") ShippingAddressRequest form,
      BindingResult bindingResult,
      Model model,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    AuthSession auth = viewModelHelper.addLayoutAttributes(model, session);
    AuthSession customer = auth != null && auth.isCustomer() ? auth : null;

    if (customer == null) {
      return "redirect:/checkout";
    }
    List<CartItem> items = cartService.getItems(session, customer);
    if (items.isEmpty()) {
      return "redirect:/cart";
    }
    if (bindingResult.hasErrors()) {
      populateCheckoutModel(model, session, customer);
      return "checkout/start";
    }

    long subtotalCents = cartService.getSubtotalCents(items);
    Order order = orderService.createOrder(customer, items, subtotalCents, form.toDomain());
    String redirectUrl = appProperties.getBaseUrl() + "/orders/" + order.getId();
    PaymentLinkCreationResult result = paymentLinkService.createPaymentLink(order.getId(), subtotalCents, redirectUrl);

    if (result instanceof PaymentLinkCreationResult.Created created) {
      orderService.attachPaymentLink(customer, order.getId(), created.link().token());
      cartService.clear(session, customer);
      return "redirect:/checkout/" + created.link().token();
    }

    // KYC-pending or a proxy/network failure: the order still exists (visible in Orders), it
    // just never got a payment link - surfaced honestly on the order detail page rather than
    // silently discarded.
    String notice =
        result instanceof PaymentLinkCreationResult.KycRequired kyc
            ? kyc.message()
            : ((PaymentLinkCreationResult.Failed) result).message();
    if (result instanceof PaymentLinkCreationResult.KycRequired) {
      orderService.markPaymentPending(customer, order.getId());
    }
    cartService.clear(session, customer);
    redirectAttributes.addFlashAttribute("checkoutNotice", notice);
    return "redirect:/orders/" + order.getId();
  }

  @GetMapping("/{token}")
  public String payment(@PathVariable String token, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    model.addAttribute("token", token);
    return "checkout/payment";
  }

  @GetMapping(value = "/{token}/status", produces = MediaType.APPLICATION_JSON_VALUE)
  @ResponseBody
  public Map<String, Object> status(@PathVariable String token) {
    Map<String, Object> response = new LinkedHashMap<>();
    try {
      PaymentLink link = paymentLinkService.getPublicStatus(token);
      response.put("status", link.status());
      response.put("amount", link.amount());
      response.put("currency", link.currency());
      response.put("network", link.network());
      response.put("address", link.address());
      response.put("expiresAt", link.expiresAt());
    } catch (RuntimeException e) {
      response.put("error", e.getMessage());
    }
    return response;
  }

  private void populateCheckoutModel(Model model, HttpSession session, AuthSession auth) {
    List<CartItem> items = cartService.getItems(session, auth);
    long subtotalCents = cartService.getSubtotalCents(items);
    String currency = items.isEmpty() ? "USD" : items.get(0).currency();
    model.addAttribute("items", items);
    model.addAttribute("subtotalCents", subtotalCents);
    model.addAttribute("currency", currency);
    model.addAttribute("formattedSubtotal", Formatting.formatMoney(subtotalCents, currency));
    model.addAttribute("cartEmpty", items.isEmpty());
    model.addAttribute("isCustomer", auth != null && auth.isCustomer());
  }
}
