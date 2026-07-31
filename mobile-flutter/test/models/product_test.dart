import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_showcase_ecommerce/models/product.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        '_id': 'prod_1',
        'name': 'Enamel Mug',
        'slug': 'enamel-mug',
        'description': 'A sturdy camp mug.',
        'priceCents': 1800,
        'currency': 'USD',
        'imageUrl': 'https://example.com/mug.png',
        'category': 'Kitchen',
        'stock': 5,
        'isActive': true,
        'sellerId': 'seller_1',
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

  group('Product.fromJson', () {
    test('parses required and optional fields', () {
      final product = Product.fromJson(baseJson());
      expect(product.id, 'prod_1');
      expect(product.name, 'Enamel Mug');
      expect(product.priceCents, 1800);
      expect(product.inStock, isTrue);
    });

    test('defaults missing numeric/boolean fields safely', () {
      final json = baseJson()
        ..remove('priceCents')
        ..remove('stock')
        ..remove('isActive');
      final product = Product.fromJson(json);
      expect(product.priceCents, 0);
      expect(product.stock, 0);
      expect(product.inStock, isFalse);
      expect(product.isActive, isTrue);
    });

    test('images combines imageUrl and galleryJson', () {
      final json = baseJson()
        ..['galleryJson'] =
            '["https://example.com/a.png","https://example.com/b.png"]';
      final product = Product.fromJson(json);
      expect(product.images, [
        'https://example.com/mug.png',
        'https://example.com/a.png',
        'https://example.com/b.png',
      ]);
    });

    test('images omits a blank main image but keeps gallery entries', () {
      final json = baseJson()
        ..remove('imageUrl')
        ..['galleryJson'] = '["https://example.com/a.png"]';
      final product = Product.fromJson(json);
      expect(product.images, ['https://example.com/a.png']);
    });
  });

  group('slugify', () {
    test('lowercases and hyphenates the name', () {
      expect(slugify('Enamel Mug'), startsWith('enamel-mug-'));
    });

    test('strips characters that are not alphanumeric', () {
      expect(slugify("Chef's Knife!!"), startsWith('chef-s-knife-'));
    });

    test('falls back to a bare suffix for an empty/symbol-only name', () {
      final result = slugify('!!!');
      expect(result, isNot(startsWith('-')));
      expect(result, isNotEmpty);
    });
  });
}
