package dev.mudbase.showcase.ecommerce.auth;

import dev.mudbase.showcase.ecommerce.mudbase.AuthResult;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseAuthClient;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Bridges the Spring {@code HttpSession} to Mudbase auth. The JWT lives here, server-side, for
 * the life of the session - never sent to client JS (rendered pages get plain HTML/CSS/minimal
 * polling JS only, no token in scope).
 */
@Component
public class SessionAuthService {

  static final String SESSION_KEY = "mudbase.auth";

  private final MudbaseAuthClient authClient;

  public SessionAuthService(MudbaseAuthClient authClient) {
    this.authClient = authClient;
  }

  public Optional<AuthSession> current(HttpSession session) {
    Object attribute = session.getAttribute(SESSION_KEY);
    return attribute instanceof AuthSession auth ? Optional.of(auth) : Optional.empty();
  }

  public Optional<AuthSession> signedInUser(HttpSession session) {
    return current(session).filter(AuthSession::isSignedIn);
  }

  /**
   * A bearer token good enough for the products collection's "authenticated role, read-only"
   * permission: the signed-in user's own token when there is one, otherwise a lazily-created
   * anonymous guest session cached for the rest of this HttpSession - mirrors the reference web
   * app's "anonymous session on first visit" behavior (see build-plan.md "Auth Flow"), just held
   * server-side instead of in the browser.
   */
  public String publicReadToken(HttpSession session) {
    Optional<AuthSession> existing = current(session);
    if (existing.isPresent()) {
      return existing.get().getToken();
    }
    AuthResult anonymous = authClient.createAnonymousSession();
    session.setAttribute(SESSION_KEY, AuthSession.anonymous(anonymous.getToken(), anonymous.getUserId()));
    return anonymous.getToken();
  }

  public void establish(HttpSession session, AuthResult result) {
    session.setAttribute(
        SESSION_KEY,
        new AuthSession(
            result.getToken(),
            result.getUserId(),
            result.getEmail(),
            result.getFirstName(),
            result.getLastName(),
            result.getCustomRole(),
            false));
  }

  public void logout(HttpSession session) {
    current(session).filter(AuthSession::isSignedIn).ifPresent(auth -> authClient.logout(auth.getToken()));
    session.removeAttribute(SESSION_KEY);
    session.removeAttribute(GuestCartHolder.SESSION_KEY);
  }
}
