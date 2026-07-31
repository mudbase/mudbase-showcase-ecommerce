package dev.mudbase.showcase.ecommerce.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Optional;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Gates the seller dashboard and product management pages. This mirrors the reference app's
 * SellerGuard component: a UX gate only - the real security boundary is Mudbase's own
 * `seller`-role collection permissions, enforced server-side on every write regardless of what
 * this interceptor does.
 */
public class RequireSellerInterceptor implements HandlerInterceptor {

  private final SessionAuthService sessionAuthService;

  public RequireSellerInterceptor(SessionAuthService sessionAuthService) {
    this.sessionAuthService = sessionAuthService;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    Optional<AuthSession> auth = sessionAuthService.signedInUser(request.getSession());
    if (auth.isPresent() && auth.get().isSeller()) {
      return true;
    }
    response.setStatus(HttpServletResponse.SC_FOUND);
    response.setHeader("Location", request.getContextPath() + "/");
    return false;
  }
}
