package dev.mudbase.showcase.ecommerce.service;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.mudbase.showcase.ecommerce.config.CheckoutProxyProperties;
import dev.mudbase.showcase.ecommerce.config.MudbaseClientFactory;
import dev.mudbase.showcase.ecommerce.domain.PaymentLink;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.Map;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.springframework.stereotype.Service;

/**
 * Payment Link creation is delegated to the already-deployed reference Next.js app's Route
 * Handler ({@code POST /api/checkout/pay-link}) rather than implemented here directly - creating
 * a Payment Link requires a live org owner/admin bearer token with no API-key path, and every
 * per-language reimplementation of this storefront independently rotating that single-use
 * merchant refresh token would be a real race condition if several ran concurrently. Reading a
 * payment link's live status, by contrast, is a public, unauthenticated Mudbase endpoint, so this
 * app calls {@code GET /api/payment-links/:token} on cloud.mudbase.dev directly.
 */
@Service
public class PaymentLinkService {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  private final OkHttpClient httpClient;
  private final CheckoutProxyProperties checkoutProxyProperties;
  private final MudbaseClientFactory clientFactory;

  public PaymentLinkService(MudbaseClientFactory clientFactory, CheckoutProxyProperties checkoutProxyProperties) {
    this.clientFactory = clientFactory;
    this.httpClient = clientFactory.rawHttpClient();
    this.checkoutProxyProperties = checkoutProxyProperties;
  }

  public PaymentLinkCreationResult createPaymentLink(String orderId, long amountCents, String redirectUrl) {
    String amount = BigDecimal.valueOf(amountCents, 2).setScale(2, RoundingMode.HALF_UP).toPlainString();
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("orderId", orderId);
    body.put("amount", amount);
    body.put("currency", "USDC");
    body.put("network", "POLYGON");
    body.put("redirectUrl", redirectUrl);

    String requestJson;
    try {
      requestJson = MAPPER.writeValueAsString(body);
    } catch (Exception e) {
      return new PaymentLinkCreationResult.Failed("Could not build the payment request");
    }

    Request request =
        new Request.Builder()
            .url(checkoutProxyProperties.payLinkEndpoint())
            .post(RequestBody.create(requestJson, MediaType.parse("application/json")))
            .build();

    try (Response response = httpClient.newCall(request).execute()) {
      String responseBody = response.body() != null ? response.body().string() : "";
      if (response.code() == 403) {
        ErrorPayload error = parseError(responseBody);
        return new PaymentLinkCreationResult.KycRequired(
            error != null && error.error != null
                ? error.error
                : "This store's payments are still pending identity verification.");
      }
      if (!response.isSuccessful()) {
        ErrorPayload error = parseError(responseBody);
        return new PaymentLinkCreationResult.Failed(
            error != null && error.error != null ? error.error : "Couldn't start payment. Please try again.");
      }
      CreatedPayload payload = MAPPER.readValue(responseBody, CreatedPayload.class);
      if (payload.link == null) {
        return new PaymentLinkCreationResult.Failed("Payment link response was empty.");
      }
      return new PaymentLinkCreationResult.Created(
          new PaymentLink(
              payload.link.token,
              payload.link.amount,
              payload.link.currency,
              payload.link.network,
              payload.link.address,
              payload.link.status != null ? payload.link.status : "pending",
              payload.link.expiresAt));
    } catch (IOException e) {
      return new PaymentLinkCreationResult.Failed("Couldn't reach the payment service. Please try again.");
    }
  }

  public PaymentLink getPublicStatus(String token) {
    Request request = new Request.Builder().url(clientFactory.baseUrl() + "/api/payment-links/" + token).get().build();
    try (Response response = httpClient.newCall(request).execute()) {
      String responseBody = response.body() != null ? response.body().string() : "";
      if (!response.isSuccessful()) {
        ErrorPayload error = parseError(responseBody);
        throw new IllegalStateException(
            error != null && error.error != null ? error.error : "Payment link not available (" + response.code() + ")");
      }
      CreatedPayload payload = MAPPER.readValue(responseBody, CreatedPayload.class);
      if (payload.link == null) {
        throw new IllegalStateException("Payment link not found.");
      }
      return new PaymentLink(
          payload.link.token,
          payload.link.amount,
          payload.link.currency,
          payload.link.network,
          payload.link.address,
          payload.link.status != null ? payload.link.status : "pending",
          payload.link.expiresAt);
    } catch (IOException e) {
      throw new IllegalStateException("Couldn't reach Mudbase to check payment status.", e);
    }
  }

  private ErrorPayload parseError(String body) {
    try {
      return MAPPER.readValue(body, ErrorPayload.class);
    } catch (Exception e) {
      return null;
    }
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  private static class CreatedPayload {
    public LinkPayload link;
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  private static class LinkPayload {
    public String token;
    public String amount;
    public String currency;
    public String network;
    public String address;
    public String status;
    public String expiresAt;
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  private static class ErrorPayload {
    public String error;
    public String reason;
  }
}
