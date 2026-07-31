import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_showcase_ecommerce/core/json_field.dart';

void main() {
  group('parseJsonObjectList', () {
    test('parses a JSON array of objects', () {
      const raw =
          '[{"productId":"p1","quantity":2},{"productId":"p2","quantity":1}]';
      final result = parseJsonObjectList(raw);
      expect(result, hasLength(2));
      expect(result.first['productId'], 'p1');
    });

    test('returns an empty list for null input', () {
      expect(parseJsonObjectList(null), isEmpty);
    });

    test('returns an empty list for empty string input', () {
      expect(parseJsonObjectList(''), isEmpty);
    });

    test('returns an empty list for malformed JSON rather than throwing', () {
      expect(parseJsonObjectList('not json'), isEmpty);
    });

    test('returns an empty list when the JSON is a valid object, not an array',
        () {
      expect(parseJsonObjectList('{"a":1}'), isEmpty);
    });
  });

  group('parseJsonStringList', () {
    test('parses a JSON array of strings', () {
      expect(parseJsonStringList('["a.png","b.png"]'), ['a.png', 'b.png']);
    });

    test('drops non-string entries rather than throwing', () {
      expect(parseJsonStringList('["a.png", 1, null]'), ['a.png']);
    });

    test('returns an empty list for null input', () {
      expect(parseJsonStringList(null), isEmpty);
    });
  });

  group('parseJsonObject', () {
    test('parses a JSON object', () {
      final result = parseJsonObject('{"fullName":"Ada Lovelace"}');
      expect(result, isNotNull);
      expect(result!['fullName'], 'Ada Lovelace');
    });

    test('returns null for null input', () {
      expect(parseJsonObject(null), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(parseJsonObject('{not valid'), isNull);
    });

    test('returns null when the JSON is a valid array, not an object', () {
      expect(parseJsonObject('[1,2,3]'), isNull);
    });
  });

  group('stringifyJsonField', () {
    test('round-trips through parseJsonObjectList', () {
      final items = [
        {'productId': 'p1', 'quantity': 3},
      ];
      final encoded = stringifyJsonField(items);
      final decoded = parseJsonObjectList(encoded);
      expect(decoded.first['productId'], 'p1');
      expect(decoded.first['quantity'], 3);
    });
  });
}
