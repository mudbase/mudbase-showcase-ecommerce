import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_showcase_ecommerce/core/formatters.dart';

void main() {
  group('formatMoney', () {
    test('formats whole-dollar USD amounts', () {
      expect(formatMoney(2500, 'USD'), r'$25.00');
    });

    test('formats cents correctly', () {
      expect(formatMoney(1999, 'USD'), r'$19.99');
    });

    test('formats zero', () {
      expect(formatMoney(0, 'USD'), r'$0.00');
    });

    test('falls back to the raw currency code when not recognized', () {
      expect(formatMoney(500, 'USDC'), 'USDC 5.00');
    });
  });

  group('discountPercent', () {
    test('returns null when there is no compare-at price', () {
      expect(discountPercent(1000, null), isNull);
    });

    test('returns null when compare-at price is not higher than the price', () {
      expect(discountPercent(1000, 1000), isNull);
      expect(discountPercent(1000, 900), isNull);
    });

    test('computes the rounded percentage off', () {
      expect(discountPercent(750, 1000), 25);
    });
  });

  group('shortOrderId', () {
    test('returns the last six characters, uppercased', () {
      expect(shortOrderId('64f0a1b2c3d4e5f6a7b8c9d0'), 'B8C9D0');
    });

    test('returns the whole id uppercased when shorter than six characters',
        () {
      expect(shortOrderId('abc'), 'ABC');
    });
  });
}
