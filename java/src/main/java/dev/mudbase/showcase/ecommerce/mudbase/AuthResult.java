package dev.mudbase.showcase.ecommerce.mudbase;

/** Normalized result of any Mudbase auth call (register, login, anonymous session). */
public class AuthResult {

  private final String token;
  private final String userId;
  private final String email;
  private final String firstName;
  private final String lastName;
  private final String customRole;
  private final boolean requireVerification;
  private final String refreshToken;

  public AuthResult(
      String token,
      String userId,
      String email,
      String firstName,
      String lastName,
      String customRole,
      boolean requireVerification) {
    this(token, userId, email, firstName, lastName, customRole, requireVerification, null);
  }

  public AuthResult(
      String token,
      String userId,
      String email,
      String firstName,
      String lastName,
      String customRole,
      boolean requireVerification,
      String refreshToken) {
    this.token = token;
    this.userId = userId;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    this.customRole = customRole;
    this.requireVerification = requireVerification;
    this.refreshToken = refreshToken;
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

  public String getCustomRole() {
    return customRole;
  }

  public boolean isRequireVerification() {
    return requireVerification;
  }

  public String getRefreshToken() {
    return refreshToken;
  }
}
