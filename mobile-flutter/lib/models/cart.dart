import '../core/json_field.dart';

class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.quantity,
    this.imageUrl,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      imageUrl: json['imageUrl'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  final String productId;
  final String name;
  final int priceCents;
  final String currency;
  final String? imageUrl;
  final int quantity;

  int get lineTotalCents => priceCents * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      productId: productId,
      name: name,
      priceCents: priceCents,
      currency: currency,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'priceCents': priceCents,
        'currency': currency,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'quantity': quantity,
      };
}

/// The signed-in customer's persisted cart - one document per user in the
/// `carts` collection, ownership-scoped (`customer` role, `{userId:
/// "$userId"}`). There is no native upsert endpoint, so callers must read
/// first and then create-or-update (see `CartRepository`).
class Cart {
  const Cart({required this.id, required this.userId, required this.items});

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['_id'] as String,
      userId: json['userId'] as String? ?? '',
      items: parseJsonObjectList(json['itemsJson'] as String?)
          .map(CartItem.fromJson)
          .toList(),
    );
  }

  final String id;
  final String userId;
  final List<CartItem> items;

  int get subtotalCents =>
      items.fold(0, (sum, item) => sum + item.lineTotalCents);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}
