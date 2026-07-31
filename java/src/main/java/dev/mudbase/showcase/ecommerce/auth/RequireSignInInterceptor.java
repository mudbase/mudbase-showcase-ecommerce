package dev.mudbase.showcase.ecommerce.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import org.springframework.web.servlet.HandlerInterceptor;

/** Gates any real-account-only page (order history) - guests are sent to /login and back. */
public class RequireSignInInterceptor implements HandlerInterceptor {

  private final SessionAuthService sessionAuthService;

  public RequireSignInInterceptor(SessionAuthService sessionAuthService) {
    this.sessionAuthService = sessionAuthService;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    if (sessionAuthService.signedInUser(request.getSession()).isPresent()) {
      return true;
    }
    String redirectTo = request.getRequestURI()
        + (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    String encoded = URLEncoder.encode(redirectTo, StandardCharsets.UTF_8);
    response.setStatus(HttpServletResponse.SC_FOUND);
    response.setHeader("Location", request.getContextPath() + "/login?redirect=" + encoded);
    return false;
  }
}
