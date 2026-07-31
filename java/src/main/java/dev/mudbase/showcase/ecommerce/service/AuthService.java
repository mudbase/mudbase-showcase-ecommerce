package dev.mudbase.showcase.ecommerce.service;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.mudbase.AuthResult;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseAuthClient;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Service;

/**
 * Registration is always role-hidden and customer-only from the public register form, matching
 * the reference app; a `seller` account is provisioned out-of-band and simply signs in through
 * the same login form (login isn't role-scoped).
 */
@Service
public class AuthService {

  private final MudbaseAuthClient authClient;
  private final SessionAuthService sessionAuthService;
  private final CartService cartService;

  public AuthService(MudbaseAuthClient authClient, SessionAuthService sessionAuthService, CartService cartService) {
    this.authClient = authClient;
    this.sessionAuthService = sessionAuthService;
    this.cartService = cartService;
  }

  public AuthSession registerCustomer(
      HttpSession session, String email, String password, String firstName, String lastName, boolean agreedToTerms) {
    AuthResult result = authClient.registerWithRole("customer", email, password, firstName, lastName, agreedToTerms);
    return establishAndMigrateCart(session, result);
  }

  public AuthSession login(HttpSession session, String email, String password) {
    AuthResult result = authClient.login(email, password);
    return establishAndMigrateCart(session, result);
  }

  private AuthSession establishAndMigrateCart(HttpSession session, AuthResult result) {
    sessionAuthService.establish(session, result);
    AuthSession established = sessionAuthService.current(session).orElseThrow();
    if (established.isCustomer()) {
      cartService.migrateGuestCartToServer(session, established);
    }
    return established;
  }

  public void logout(HttpSession session) {
    sessionAuthService.logout(session);
  }
}
