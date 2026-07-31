import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_showcase_ecommerce/models/cart.dart';

void main() {
  group('CartItem', () {
    test('computes the line total', () {
      const item = CartItem(
        productId: 'p1',
        name: 'Mug',
        priceCents: 1500,
        currency: 'USD',
        quantity: 3,
      );
      expect(item.lineTotalCents, 4500);
    });

    test('copyWith replaces only the quantity', () {
      const item = CartItem(
        productId: 'p1',
        name: 'Mug',
        priceCents: 1500,
        currency: 'USD',
        quantity: 1,
      );
      final updated = item.copyWith(quantity: 4);
      expect(updated.quantity, 4);
      expect(updated.productId, item.productId);
      expect(updated.priceCents, item.priceCents);
    });

    test('toJson/fromJson round-trips', () {
      const item = CartItem(
        productId: 'p1',
        name: 'Mug',
        priceCents: 1500,
        currency: 'USD',
        imageUrl: 'https://example.com/mug.png',
        quantity: 2,
      );
      final restored = CartItem.fromJson(item.toJson());
      expect(restored.productId, item.productId);
      expect(restored.quantity, item.quantity);
      expect(restored.imageUrl, item.imageUrl);
    });
  });

  group('Cart', () {
    test('parses itemsJson and computes subtotal/itemCount', () {
      final cart = Cart.fromJson({
        '_id': 'cart_1',
        'userId': 'user_1',
        'itemsJson':
            '[{"productId":"p1","name":"Mug","priceCents":1000,"currency":"USD","quantity":2},'
                '{"productId":"p2","name":"Plate","priceCents":500,"currency":"USD","quantity":1}]',
      });
      expect(cart.items, hasLength(2));
      expect(cart.subtotalCents, 2500);
      expect(cart.itemCount, 3);
    });

    test('treats a missing itemsJson as an empty cart', () {
      final cart = Cart.fromJson({'_id': 'cart_1', 'userId': 'user_1'});
      expect(cart.items, isEmpty);
      expect(cart.subtotalCents, 0);
    });
  });
}
