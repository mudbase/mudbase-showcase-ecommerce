package dev.mudbase.showcase.ecommerce.mudbase;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.mudbase.showcase.ecommerce.config.MudbaseClientFactory;
import dev.mudbase.sdk.ApiException;
import dev.mudbase.sdk.api.AuthenticationApi;
import dev.mudbase.sdk.model.CreateAnonymousSession200Response;
import dev.mudbase.sdk.model.CreateAnonymousSessionRequest;
import dev.mudbase.sdk.model.RefreshToken200Response;
import dev.mudbase.sdk.model.RefreshTokenRequest;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.springframework.stereotype.Component;

/**
 * Auth calls against a provisioned Mudbase project: register (role-scoped), login, logout, and
 * the anonymous guest session used for pre-login catalog browsing.
 *
 * <p><b>Why registration bypasses the generated SDK method.</b> {@code
 * MultiRoleFeatureApi.registerWithRole} posts a {@code RegisterWithRoleRequest} that only has
 * {@code email}/{@code password}/{@code firstName}/{@code lastName}/{@code projectId} - the live
 * endpoint's validator additionally requires {@code agreedToTerms} (confirmed by the reference
 * Next.js app's own client, which sends it explicitly and notes "a direct API call without it is
 * rejected"). The generated request model has no field for it, and the generated method's return
 * type is {@code void} (the response body isn't modeled for this endpoint either). Rather than
 * force a mismatched typed call, this one endpoint is invoked directly over the SDK's own shared
 * OkHttp client and base path, with a hand-written response shape mirroring the sibling {@code
 * RegisterLocalUser201Response}/{@code RegisterLocalUser201ResponseUser} models (the same
 * underlying local-auth registration handler, just role-scoped) - see README "Known limitations".
 *
 * <p><b>Why login also bypasses the generated SDK method.</b> {@code
 * AuthenticationApi.loginLocalUser} deserializes its response with the generated {@code
 * LoginLocalUser200ResponseUser} model via Gson, which - unlike the SDK's Jackson-based raw-call
 * path used elsewhere in this app - hard-fails with an {@code IllegalArgumentException} the
 * instant the response JSON contains any property the model doesn't declare. Every account
 * created through this project's Multi-Role feature (i.e. every seller/customer this app ever
 * creates or signs in) gets a login response whose {@code user} object carries both {@code role}
 * and {@code customRole} - the generated model only declares {@code role} - so this call fails
 * with a 500 for every real signed-up user, every time, confirmed against the live API during
 * this app's own end-to-end testing. Same "raw call over the SDK's own shared OkHttpClient, same base
 * path and bearer header, parsed leniently with Jackson's {@code ignoreUnknown}" fix already
 * applied to registration and to {@link MudbaseDataClient#listRaw} for their own generated-model
 * mismatches - see those for the established pattern. Worth flagging back to Mudbase alongside
 * the other two: the login endpoint's OpenAPI spec is missing a field its own live handler
 * always returns for Multi-Role accounts.
 */
@Component
public class MudbaseAuthClient {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  private final MudbaseClientFactory clientFactory;

  public MudbaseAuthClient(MudbaseClientFactory clientFactory) {
    this.clientFactory = clientFactory;
  }

  public AuthResult registerWithRole(
      String role, String email, String password, String firstName, String lastName, boolean agreedToTerms) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("email", email);
    body.put("password", password);
    body.put("firstName", firstName);
    body.put("lastName", lastName);
    body.put("agreedToTerms", agreedToTerms);
    body.put("projectId", clientFactory.projectId());

    String requestJson;
    try {
      requestJson = MAPPER.writeValueAsString(body);
    } catch (Exception e) {
      throw new IllegalStateException("Could not serialize registration request", e);
    }

    OkHttpClient httpClient = clientFactory.rawHttpClient();
    Request request =
        new Request.Builder()
            .url(clientFactory.baseUrl() + "/api/auth/local/signup/" + role)
            .post(RequestBody.create(requestJson, MediaType.parse("application/json")))
            .build();

    try (Response response = httpClient.newCall(request).execute()) {
      String responseBody = response.body() != null ? response.body().string() : "";
      if (!response.isSuccessful()) {
        throw MudbaseApiException.fromRawBody(response.code(), responseBody);
      }
      RegisterPayload payload = MAPPER.readValue(responseBody, RegisterPayload.class);
      RegisterPayload.User user = payload.user;
      return new AuthResult(
          payload.token,
          user != null ? user.id : null,
          user != null ? user.email : email,
          user != null ? user.firstName : firstName,
          user != null ? user.lastName : lastName,
          user != null ? user.customRole : role,
          Boolean.TRUE.equals(payload.requireVerification),
          payload.refreshToken);
    } catch (IOException e) {
      throw new MudbaseApiException("Could not reach Mudbase to register", 502, null, e);
    }
  }

  public AuthResult login(String email, String password) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("email", email);
    body.put("password", password);
    body.put("projectId", clientFactory.projectId());

    String requestJson;
    try {
      requestJson = MAPPER.writeValueAsString(body);
    } catch (Exception e) {
      throw new IllegalStateException("Could not serialize login request", e);
    }

    OkHttpClient httpClient = clientFactory.rawHttpClient();
    Request request =
        new Request.Builder()
            .url(clientFactory.baseUrl() + "/api/auth/local/login")
            .post(RequestBody.create(requestJson, MediaType.parse("application/json")))
            .build();

    try (Response response = httpClient.newCall(request).execute()) {
      String responseBody = response.body() != null ? response.body().string() : "";
      if (!response.isSuccessful()) {
        throw MudbaseApiException.fromRawBody(response.code(), responseBody);
      }
      LoginPayload payload = MAPPER.readValue(responseBody, LoginPayload.class);
      LoginPayload.User user = payload.user;
      return new AuthResult(
          payload.token,
          user != null ? user.id : null,
          user != null ? user.email : email,
          user != null ? user.firstName : null,
          user != null ? user.lastName : null,
          // Real Multi-Role accounts carry both "role" and "customRole" on this response - see
          // class javadoc "Why login also bypasses the generated SDK method". customRole is the
          // project app-role this app actually cares about; fall back to role only for the rare
          // account shape that predates the Multi-Role feature and never got a customRole set.
          user != null && user.customRole != null ? user.customRole : (user != null ? user.role : null),
          false,
          payload.refreshToken);
    } catch (IOException e) {
      throw new MudbaseApiException("Could not reach Mudbase to log in", 502, null, e);
    }
  }

  public void logout(String bearerToken) {
    AuthenticationApi authApi = clientFactory.authApi(bearerToken);
    try {
      authApi.logoutLocalUser();
    } catch (ApiException e) {
      // Best-effort revoke, matching the reference app: a failed server-side revoke must never
      // block the user from being signed out locally.
    }
  }

  public AuthResult createAnonymousSession() {
    AuthenticationApi authApi = clientFactory.authApi(null);
    CreateAnonymousSessionRequest request = new CreateAnonymousSessionRequest().projectId(clientFactory.projectId());
    try {
      CreateAnonymousSession200Response response = authApi.createAnonymousSession(request);
      var user = response.getUser();
      return new AuthResult(
          response.getToken(),
          user != null ? user.getId() : null,
          null,
          null,
          null,
          null,
          false,
          response.getRefreshToken());
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  /**
   * Exchanges a stored refresh token for a new access/refresh token pair. Used by {@link
   * dev.mudbase.showcase.ecommerce.auth.SessionAuthService#recoverFromUnauthorized} to
   * transparently recover from a 401 caused by an expired access token - see that method for the
   * retry-once policy. Mudbase rotates the refresh token on every use (the previous one is
   * invalidated - reuse is treated as a stolen-token signal), so the caller must persist the
   * {@code refreshToken} on this result, not just the {@code token}.
   */
  public AuthResult refresh(String refreshToken) {
    AuthenticationApi authApi = clientFactory.authApi(null);
    RefreshTokenRequest request = new RefreshTokenRequest().refreshToken(refreshToken);
    try {
      RefreshToken200Response response = authApi.refreshToken(request);
      return new AuthResult(
          response.getToken(),
          null,
          null,
          null,
          null,
          null,
          false,
          response.getRefreshToken() != null ? response.getRefreshToken() : refreshToken);
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  /** Hand-written mirror of RegisterLocalUser201Response - see class javadoc for why. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  private static class RegisterPayload {
    public String message;
    public Boolean requireVerification;
    public String token;
    public String refreshToken;
    public Integer expiresIn;
    public User user;

    @JsonIgnoreProperties(ignoreUnknown = true)
    static class User {
      public String id;
      public String email;
      public String firstName;
      public String lastName;
      public Boolean emailVerified;
      public String customRole;
    }
  }

  /**
   * Hand-written mirror of LoginLocalUser200Response, deliberately Jackson-lenient ({@code
   * ignoreUnknown}) rather than the generated Gson model's strict field validation - see class
   * javadoc "Why login also bypasses the generated SDK method". Declares both {@code role} and
   * {@code customRole} since real Multi-Role accounts' login responses carry both.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  private static class LoginPayload {
    public String message;
    public String token;
    public String refreshToken;
    public Integer expiresIn;
    public User user;

    @JsonIgnoreProperties(ignoreUnknown = true)
    static class User {
      public String id;
      public String email;
      public String firstName;
      public String lastName;
      public String role;
      public String customRole;
      public Boolean emailVerified;
      public Boolean twoFactorEnabled;
    }
  }
}
