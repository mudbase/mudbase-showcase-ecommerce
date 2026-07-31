package dev.mudbase.showcase.ecommerce.domain;

/** A Mudbase Payment Link (non-custodial stablecoin), as returned by the public status endpoint. */
public record PaymentLink(
    String token, String amount, String currency, String network, String address, String status, String expiresAt) {

  public boolean isPaid() {
    return "paid".equals(status);
  }

  public boolean isTerminalFailure() {
    return "expired".equals(status) || "cancelled".equals(status);
  }

  public boolean isPending() {
    return !isPaid() && !isTerminalFailure();
  }
}
