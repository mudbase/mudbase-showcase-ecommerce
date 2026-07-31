import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_showcase_ecommerce/models/order.dart';

void main() {
  group('OrderStatus', () {
    test('fromWire maps every documented wire value', () {
      expect(OrderStatus.fromWire('pending'), OrderStatus.pending);
      expect(OrderStatus.fromWire('awaiting_payment'),
          OrderStatus.awaitingPayment);
      expect(OrderStatus.fromWire('paid'), OrderStatus.paid);
      expect(OrderStatus.fromWire('shipped'), OrderStatus.shipped);
      expect(OrderStatus.fromWire('delivered'), OrderStatus.delivered);
      expect(OrderStatus.fromWire('cancelled'), OrderStatus.cancelled);
    });

    test('fromWire falls back to pending for an unrecognized value', () {
      expect(OrderStatus.fromWire('something_new'), OrderStatus.pending);
      expect(OrderStatus.fromWire(null), OrderStatus.pending);
    });

    test('nextFulfillmentStatus only advances paid and shipped', () {
      expect(OrderStatus.paid.nextFulfillmentStatus, OrderStatus.shipped);
      expect(OrderStatus.shipped.nextFulfillmentStatus, OrderStatus.delivered);
      expect(OrderStatus.pending.nextFulfillmentStatus, isNull);
      expect(OrderStatus.awaitingPayment.nextFulfillmentStatus, isNull);
      expect(OrderStatus.delivered.nextFulfillmentStatus, isNull);
      expect(OrderStatus.cancelled.nextFulfillmentStatus, isNull);
    });
  });

  group('Order.fromJson', () {
    Map<String, dynamic> baseJson() => {
          '_id': 'order_1',
          'userId': 'user_1',
          'itemsJson':
              '[{"productId":"p1","name":"Mug","priceCents":1000,"quantity":2}]',
          'subtotalCents': 2000,
          'currency': 'USD',
          'orderStatus': 'awaiting_payment',
          'paymentStatus': 'unpaid',
          'createdAt': '2026-01-01T00:00:00.000Z',
        };

    test('parses line items and status enums', () {
      final order = Order.fromJson(baseJson());
      expect(order.items, hasLength(1));
      expect(order.items.first.name, 'Mug');
      expect(order.orderStatus, OrderStatus.awaitingPayment);
      expect(order.paymentStatus, OrderPaymentStatus.unpaid);
      expect(order.needsPayment, isFalse); // no paymentLinkToken yet
    });

    test('needsPayment is true once a link exists and payment is not complete',
        () {
      final json = baseJson()..['paymentLinkToken'] = 'tok_123';
      final order = Order.fromJson(json);
      expect(order.needsPayment, isTrue);
    });

    test('needsPayment is false once paid', () {
      final json = baseJson()
        ..['paymentLinkToken'] = 'tok_123'
        ..['paymentStatus'] = 'paid';
      final order = Order.fromJson(json);
      expect(order.needsPayment, isFalse);
    });

    test('parses the shipping address from shippingAddressJson', () {
      final json = baseJson()
        ..['shippingAddressJson'] =
            '{"fullName":"Ada Lovelace","line1":"1 Analytical Way",'
                '"city":"London","region":"London","postalCode":"E1 1AA","country":"UK"}';
      final order = Order.fromJson(json);
      expect(order.shippingAddress, isNotNull);
      expect(order.shippingAddress!.fullName, 'Ada Lovelace');
    });
  });
}
