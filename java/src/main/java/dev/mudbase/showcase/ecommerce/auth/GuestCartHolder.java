package dev.mudbase.showcase.ecommerce.auth;

import dev.mudbase.showcase.ecommerce.domain.CartItem;
import jakarta.servlet.http.HttpSession;
import java.util.ArrayList;
import java.util.List;

/**
 * A "customer" application role is required to persist a cart in the `carts` collection - Mudbase's
 * ownership-conditioned permission only grants create/read/update/delete to the `customer`
 * customRole (see plan/build-plan.md in the reference web app); a guest (anonymous or not yet
 * signed in) is denied. This holder keeps the cart in the servlet HttpSession until the shopper
 * has a real customer account, mirroring the reference app's localStorage guest cart - then
 * CartService migrates it into the server-side cart right after registration/login succeeds.
 */
public final class GuestCartHolder {

  static final String SESSION_KEY = "mudbase.guestCart";

  private GuestCartHolder() {}

  @SuppressWarnings("unchecked")
  public static List<CartItem> get(HttpSession session) {
    Object attribute = session.getAttribute(SESSION_KEY);
    if (attribute instanceof List<?> list) {
      return new ArrayList<>((List<CartItem>) list);
    }
    return new ArrayList<>();
  }

  public static void set(HttpSession session, List<CartItem> items) {
    session.setAttribute(SESSION_KEY, new ArrayList<>(items));
  }

  public static void clear(HttpSession session) {
    session.removeAttribute(SESSION_KEY);
  }
}
