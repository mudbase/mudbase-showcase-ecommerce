package dev.mudbase.showcase.ecommerce.domain;

/**
 * Named "orderStatus" throughout this app, never "status" - Mudbase's server-side
 * role-assignment guard treats a literal "status" field on ANY collection as a protected role
 * field and rejects writes from every non-owner/admin project end-user, sellers included. Real
 * platform constraint, not a naming preference - see README "Known limitations".
 */
public enum OrderStatus {
  pending("Pending"),
  awaiting_payment("Awaiting payment"),
  paid("Paid"),
  shipped("Shipped"),
  delivered("Delivered"),
  cancelled("Cancelled");

  private final String label;

  OrderStatus(String label) {
    this.label = label;
  }

  public String getLabel() {
    return label;
  }

  public static OrderStatus fromValue(String value, OrderStatus fallback) {
    if (value == null) {
      return fallback;
    }
    for (OrderStatus status : values()) {
      if (status.name().equals(value)) {
        return status;
      }
    }
    return fallback;
  }

  /** Badge color tone for the Thymeleaf status badge fragment. */
  public String getBadgeVariant() {
    return switch (this) {
      case delivered, paid -> "success";
      case cancelled -> "destructive";
      case awaiting_payment, pending -> "warning";
      case shipped -> "secondary";
    };
  }

  /** Mirrors the reference app's seller fulfillment queue: paid -> shipped -> delivered. */
  public OrderStatus getNextFulfillmentStatus() {
    return switch (this) {
      case paid -> shipped;
      case shipped -> delivered;
      default -> null;
    };
  }
}
