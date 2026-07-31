import '../core/json_field.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceCents,
    required this.currency,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.compareAtPriceCents,
    this.imageUrl,
    this.galleryJson,
    this.category,
    this.sellerId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      compareAtPriceCents: (json['compareAtPriceCents'] as num?)?.toInt(),
      currency: json['currency'] as String? ?? 'USD',
      imageUrl: json['imageUrl'] as String?,
      galleryJson: json['galleryJson'] as String?,
      category: json['category'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      sellerId: json['sellerId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int priceCents;
  final int? compareAtPriceCents;
  final String currency;
  final String? imageUrl;

  /// JSON-encoded array of extra image URLs - Mudbase Collections have no
  /// native array field type (see `core/json_field.dart`).
  final String? galleryJson;
  final String? category;
  final int stock;
  final bool isActive;
  final String? sellerId;
  final DateTime createdAt;

  /// Main image followed by every gallery image, de-duplicated of blanks -
  /// what the product detail carousel renders.
  List<String> get images {
    final gallery = parseJsonStringList(galleryJson);
    return [
      if (imageUrl != null && imageUrl!.isNotEmpty) imageUrl!,
      ...gallery.where((url) => url.isNotEmpty),
    ];
  }

  bool get inStock => stock > 0;
}

/// Derives a URL-safe, near-unique slug from a product name for the create
/// flow. Only used on create - editing an existing product must never
/// regenerate its slug (that would silently change the product's identity
/// out from under anything already referencing the old one).
String slugify(String name) {
  final base = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return base.isEmpty ? suffix : '$base-$suffix';
}
