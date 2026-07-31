package dev.mudbase.showcase.ecommerce.domain;

public enum PaymentStatus {
  unpaid,
  paid,
  expired,
  cancelled;

  public static PaymentStatus fromValue(String value, PaymentStatus fallback) {
    if (value == null) {
      return fallback;
    }
    for (PaymentStatus status : values()) {
      if (status.name().equals(value)) {
        return status;
      }
    }
    return fallback;
  }
}
