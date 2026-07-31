package dev.mudbase.showcase.ecommerce.mudbase;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.mudbase.showcase.ecommerce.config.MudbaseClientFactory;
import dev.mudbase.sdk.ApiException;
import dev.mudbase.sdk.api.AuthenticationApi;
import dev.mudbase.sdk.model.CreateAnonymousSession200Response;
import dev.mudbase.sdk.model.CreateAnonymousSessionRequest;
import dev.mudbase.sdk.model.LoginLocalUser200Response;
import dev.mudbase.sdk.model.LoginLocalUserRequest;
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
 * Every other auth call below uses the real generated {@link AuthenticationApi}.
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
          Boolean.TRUE.equals(payload.requireVerification));
    } catch (IOException e) {
      throw new MudbaseApiException("Could not reach Mudbase to register", 502, null, e);
    }
  }

  public AuthResult login(String email, String password) {
    AuthenticationApi authApi = clientFactory.authApi(null);
    LoginLocalUserRequest request =
        new LoginLocalUserRequest().email(email).password(password).projectId(clientFactory.projectId());
    try {
      LoginLocalUser200Response response = authApi.loginLocalUser(request);
      var user = response.getUser();
      return new AuthResult(
          response.getToken(),
          user != null ? user.getId() : null,
          user != null ? user.getEmail() : email,
          user != null ? user.getFirstName() : null,
          user != null ? user.getLastName() : null,
          // This endpoint's generated response types the field "role" (see
          // LoginLocalUser200ResponseUser) where every other user shape in this SDK calls the
          // same concept "customRole" - same semantics (the project app-role, e.g. "customer" or
          // "seller"), different generated field name for this one endpoint.
          user != null ? user.getRole() : null,
          false);
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
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
          response.getToken(), user != null ? user.getId() : null, null, null, null, null, false);
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
}
