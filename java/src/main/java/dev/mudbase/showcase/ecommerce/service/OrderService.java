package dev.mudbase.showcase.ecommerce.service;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.config.MudbaseProperties;
import dev.mudbase.showcase.ecommerce.domain.CartItem;
import dev.mudbase.showcase.ecommerce.domain.Order;
import dev.mudbase.showcase.ecommerce.domain.OrderLineItem;
import dev.mudbase.showcase.ecommerce.domain.OrderStatus;
import dev.mudbase.showcase.ecommerce.domain.ShippingAddress;
import dev.mudbase.showcase.ecommerce.mudbase.JsonFields;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseApiException;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseDataClient;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `orders` collection. Every call here runs as the caller's own JWT: a
 * `customer` may create/read/update only their own orders (Mudbase enforces the {@code {userId:
 * "$userId"}} ownership condition server-side), a `seller` may read/update every order
 * unconditionally (the fulfillment queue).
 */
@Service
public class OrderService {

  private static final int SELLER_QUEUE_PAGE_SIZE = 100;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;

  public OrderService(MudbaseDataClient dataClient, MudbaseProperties properties) {
    this.dataClient = dataClient;
    this.properties = properties;
  }

  public Order createOrder(AuthSession customer, List<CartItem> items, long subtotalCents, ShippingAddress address) {
    List<OrderLineItem> snapshot =
        items.stream().map(i -> new OrderLineItem(i.productId(), i.name(), i.priceCents(), i.quantity())).toList();

    Map<String, Object> body = new LinkedHashMap<>();
    body.put("userId", customer.getUserId());
    body.put("itemsJson", JsonFields.stringify(snapshot));
    body.put("subtotalCents", subtotalCents);
    body.put("currency", "USD");
    body.put("orderStatus", OrderStatus.awaiting_payment.name());
    body.put("shippingName", address.fullName());
    body.put("shippingAddressJson", JsonFields.stringify(address));
    body.put("paymentStatus", "unpaid");

    return Order.fromDocument(dataClient.create(customer.getToken(), properties.getOrdersCollectionId(), body));
  }

  public void attachPaymentLink(AuthSession customer, String orderId, String paymentLinkToken) {
    dataClient.update(
        customer.getToken(),
        properties.getOrdersCollectionId(),
        orderId,
        Map.of("paymentLinkToken", paymentLinkToken));
  }

  /** Payment link creation was refused (e.g. KYC pending) - surface it honestly on the order too. */
  public void markPaymentPending(AuthSession customer, String orderId) {
    dataClient.update(
        customer.getToken(),
        properties.getOrdersCollectionId(),
        orderId,
        Map.of("orderStatus", OrderStatus.pending.name()));
  }

  public List<Order> listForCustomer(AuthSession customer) {
    return dataClient
        .list(
            customer.getToken(),
            properties.getOrdersCollectionId(),
            Map.of("userId", customer.getUserId()),
            "-createdAt",
            1,
            SELLER_QUEUE_PAGE_SIZE)
        .stream()
        .map(Order::fromDocument)
        .toList();
  }

  public List<Order> listAllForSeller(AuthSession seller) {
    return dataClient
        .list(seller.getToken(), properties.getOrdersCollectionId(), Map.of(), "-createdAt", 1, SELLER_QUEUE_PAGE_SIZE)
        .stream()
        .map(Order::fromDocument)
        .toList();
  }

  public Optional<Order> findById(AuthSession auth, String id) {
    try {
      return Optional.of(Order.fromDocument(dataClient.get(auth.getToken(), properties.getOrdersCollectionId(), id)));
    } catch (MudbaseApiException e) {
      return Optional.empty();
    }
  }

  public void updateStatus(AuthSession seller, String id, OrderStatus newStatus) {
    dataClient.update(
        seller.getToken(), properties.getOrdersCollectionId(), id, Map.of("orderStatus", newStatus.name()));
  }
}
