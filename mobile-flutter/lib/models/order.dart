import '../core/json_field.dart';

class OrderLineItem {
  const OrderLineItem({
    required this.productId,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  final String productId;
  final String name;
  final int priceCents;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'priceCents': priceCents,
        'quantity': quantity,
      };
}

class ShippingAddress {
  const ShippingAddress({
    required this.fullName,
    required this.line1,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    this.line2,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      fullName: json['fullName'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }

  final String fullName;
  final String line1;
  final String? line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        'city': city,
        'region': region,
        'postalCode': postalCode,
        'country': country,
      };
}

/// Named `orderStatus`, never the literal `status` - Mudbase's server-side
/// role-assignment guard treats a field literally named `status` on ANY
/// collection as protected, rejecting writes from every project end-user
/// regardless of role or collection permissions. Real platform constraint,
/// not a typo - see the web app's README "Known limitations".
enum OrderStatus {
  pending('pending'),
  awaitingPayment('awaiting_payment'),
  paid('paid'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.wireValue);

  final String wireValue;

  static OrderStatus fromWire(String? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => OrderStatus.pending,
    );
  }

  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.awaitingPayment => 'Awaiting payment',
        OrderStatus.paid => 'Paid',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// The seller fulfillment queue's single "advance" action - mirrors the
  /// web app's `SellerOrderQueue` `NEXT_STATUS` map. Any other status has no
  /// forward action from this screen (e.g. `awaitingPayment` moves to `paid`
  /// only via the payment webhook, not a manual seller action).
  OrderStatus? get nextFulfillmentStatus => switch (this) {
        OrderStatus.paid => OrderStatus.shipped,
        OrderStatus.shipped => OrderStatus.delivered,
        _ => null,
      };
}

enum OrderPaymentStatus {
  unpaid('unpaid'),
  paid('paid'),
  expired('expired'),
  cancelled('cancelled');

  const OrderPaymentStatus(this.wireValue);

  final String wireValue;

  static OrderPaymentStatus fromWire(String? value) {
    return OrderPaymentStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => OrderPaymentStatus.unpaid,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotalCents,
    required this.currency,
    required this.orderStatus,
    required this.paymentStatus,
    required this.createdAt,
    this.shippingName,
    this.shippingAddress,
    this.paymentLinkToken,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] as String,
      userId: json['userId'] as String? ?? '',
      items: parseJsonObjectList(json['itemsJson'] as String?)
          .map(OrderLineItem.fromJson)
          .toList(),
      subtotalCents: (json['subtotalCents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      orderStatus: OrderStatus.fromWire(json['orderStatus'] as String?),
      paymentStatus:
          OrderPaymentStatus.fromWire(json['paymentStatus'] as String?),
      shippingName: json['shippingName'] as String?,
      shippingAddress: () {
        final map = parseJsonObject(json['shippingAddressJson'] as String?);
        return map == null ? null : ShippingAddress.fromJson(map);
      }(),
      paymentLinkToken: json['paymentLinkToken'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final List<OrderLineItem> items;
  final int subtotalCents;
  final String currency;
  final OrderStatus orderStatus;
  final OrderPaymentStatus paymentStatus;
  final String? shippingName;
  final ShippingAddress? shippingAddress;
  final String? paymentLinkToken;
  final DateTime createdAt;

  bool get needsPayment =>
      paymentLinkToken != null && paymentStatus != OrderPaymentStatus.paid;
}
