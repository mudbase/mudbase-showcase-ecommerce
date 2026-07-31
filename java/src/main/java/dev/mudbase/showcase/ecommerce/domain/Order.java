package dev.mudbase.showcase.ecommerce.domain;

import com.fasterxml.jackson.core.type.TypeReference;
import dev.mudbase.showcase.ecommerce.mudbase.DocumentMapper;
import dev.mudbase.showcase.ecommerce.mudbase.JsonFields;
import dev.mudbase.showcase.ecommerce.support.Formatting;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Mirrors the `orders` collection - see plan/build-plan.md in the reference web app. */
public class Order {

  private final String id;
  private final String userId;
  private final List<OrderLineItem> items;
  private final long subtotalCents;
  private final String currency;
  private final OrderStatus orderStatus;
  private final String shippingName;
  private final ShippingAddress shippingAddress;
  private final String paymentLinkToken;
  private final PaymentStatus paymentStatus;
  private final String createdAt;

  public Order(
      String id,
      String userId,
      List<OrderLineItem> items,
      long subtotalCents,
      String currency,
      OrderStatus orderStatus,
      String shippingName,
      ShippingAddress shippingAddress,
      String paymentLinkToken,
      PaymentStatus paymentStatus,
      String createdAt) {
    this.id = id;
    this.userId = userId;
    this.items = items;
    this.subtotalCents = subtotalCents;
    this.currency = currency;
    this.orderStatus = orderStatus;
    this.shippingName = shippingName;
    this.shippingAddress = shippingAddress;
    this.paymentLinkToken = paymentLinkToken;
    this.paymentStatus = paymentStatus;
    this.createdAt = createdAt;
  }

  public static Order fromDocument(Map<String, Object> doc) {
    List<OrderLineItem> items =
        JsonFields.parse(
            DocumentMapper.getString(doc, "itemsJson"), new TypeReference<List<OrderLineItem>>() {}, List.of());
    ShippingAddress address =
        JsonFields.parse(DocumentMapper.getString(doc, "shippingAddressJson"), new TypeReference<ShippingAddress>() {}, null);
    return new Order(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "userId"),
        items,
        DocumentMapper.getLong(doc, "subtotalCents", 0),
        DocumentMapper.getString(doc, "currency", "USD"),
        OrderStatus.fromValue(DocumentMapper.getString(doc, "orderStatus"), OrderStatus.pending),
        DocumentMapper.getString(doc, "shippingName"),
        address,
        DocumentMapper.getString(doc, "paymentLinkToken"),
        PaymentStatus.fromValue(DocumentMapper.getString(doc, "paymentStatus"), PaymentStatus.unpaid),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getUserId() {
    return userId;
  }

  public List<OrderLineItem> getItems() {
    return items;
  }

  public long getSubtotalCents() {
    return subtotalCents;
  }

  public String getCurrency() {
    return currency;
  }

  public OrderStatus getOrderStatus() {
    return orderStatus;
  }

  public String getShippingName() {
    return shippingName;
  }

  public ShippingAddress getShippingAddress() {
    return shippingAddress;
  }

  public String getPaymentLinkToken() {
    return paymentLinkToken;
  }

  public PaymentStatus getPaymentStatus() {
    return paymentStatus;
  }

  public String getCreatedAt() {
    return createdAt;
  }

  public String getShortOrderNumber() {
    return Formatting.shortOrderNumber(id);
  }

  public String getFormattedCreatedAt() {
    return Formatting.formatDate(createdAt);
  }

  public String getFormattedSubtotal() {
    return Formatting.formatMoney(subtotalCents, currency);
  }

  public boolean hasUnpaidPaymentLink() {
    return paymentLinkToken != null && !paymentLinkToken.isBlank() && paymentStatus != PaymentStatus.paid;
  }

  public boolean isCancelled() {
    return orderStatus == OrderStatus.cancelled;
  }

  private static final List<OrderStatus> TIMELINE_STATUSES =
      List.of(OrderStatus.pending, OrderStatus.paid, OrderStatus.shipped, OrderStatus.delivered);
  private static final List<String> TIMELINE_LABELS = List.of("Placed", "Paid", "Shipped", "Delivered");

  /** Empty when cancelled - the detail page shows a plain cancellation notice instead. */
  public List<OrderTimelineStep> getTimelineSteps() {
    if (isCancelled()) {
      return List.of();
    }
    OrderStatus effective = orderStatus == OrderStatus.awaiting_payment ? OrderStatus.pending : orderStatus;
    int currentIndex = TIMELINE_STATUSES.indexOf(effective);
    List<OrderTimelineStep> steps = new ArrayList<>();
    for (int i = 0; i < TIMELINE_STATUSES.size(); i++) {
      steps.add(new OrderTimelineStep(TIMELINE_LABELS.get(i), i <= currentIndex));
    }
    return steps;
  }
}
