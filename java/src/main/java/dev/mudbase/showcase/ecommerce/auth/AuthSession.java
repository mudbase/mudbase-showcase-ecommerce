package dev.mudbase.showcase.ecommerce.auth;

import java.io.Serializable;

/**
 * The signed-in user's Mudbase identity, held server-side in the Spring {@code HttpSession} -
 * the JWT never reaches client JS. One instance covers both real accounts (customer/seller) and
 * the lazily-created anonymous guest session used only to satisfy the products collection's
 * "authenticated role, read-only" permission while browsing before sign-in.
 */
public class AuthSession implements Serializable {

  private static final long serialVersionUID = 1L;

  private final String token;
  private final String userId;
  private final String email;
  private final String firstName;
  private final String lastName;
  private final String customRole;
  private final boolean anonymous;

  public AuthSession(
      String token,
      String userId,
      String email,
      String firstName,
      String lastName,
      String customRole,
      boolean anonymous) {
    this.token = token;
    this.userId = userId;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    this.customRole = customRole;
    this.anonymous = anonymous;
  }

  public static AuthSession anonymous(String token, String userId) {
    return new AuthSession(token, userId, null, null, null, null, true);
  }

  public String getToken() {
    return token;
  }

  public String getUserId() {
    return userId;
  }

  public String getEmail() {
    return email;
  }

  public String getFirstName() {
    return firstName;
  }

  public String getLastName() {
    return lastName;
  }

  public String getDisplayName() {
    if (firstName == null && lastName == null) {
      return email != null ? email : "Guest";
    }
    return String.join(" ", firstName != null ? firstName : "", lastName != null ? lastName : "").trim();
  }

  public String getCustomRole() {
    return customRole;
  }

  public boolean isAnonymous() {
    return anonymous;
  }

  public boolean isSignedIn() {
    return !anonymous && userId != null;
  }

  public boolean isCustomer() {
    return "customer".equals(customRole);
  }

  public boolean isSeller() {
    return "seller".equals(customRole);
  }
}
