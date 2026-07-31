import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/product.dart';

class ProductRepository {
  const ProductRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// The catalog screen's list read. Category filtering happens server-side
  /// (an exact-match filter, same shape the web app sends); search is
  /// client-side substring matching over the fetched page, since the
  /// `products` collection has no dedicated full-text search index in this
  /// showcase's schema.
  Future<List<Product>> listActive({
    required String token,
    String? category,
    String? search,
  }) async {
    final filter = <String, dynamic>{'isActive': true};
    if (category != null && category.isNotEmpty) {
      filter['category'] = category;
    }
    final docs = await _dataService.list(
      EnvConfig.productsCollectionId,
      token: token,
      filter: filter,
      limit: 100,
    );
    final products = docs.map(Product.fromJson).toList();
    final query = search?.trim().toLowerCase();
    if (query == null || query.isEmpty) return products;
    return products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
  }

  Future<Product?> getBySlug(
      {required String token, required String slug}) async {
    final docs = await _dataService.list(
      EnvConfig.productsCollectionId,
      token: token,
      filter: {'slug': slug},
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return Product.fromJson(docs.first);
  }

  Future<Product?> getById({required String token, required String id}) async {
    final doc = await _dataService.getById(
      EnvConfig.productsCollectionId,
      id,
      token: token,
    );
    return doc == null ? null : Product.fromJson(doc);
  }

  Future<List<Product>> listForSeller({
    required String token,
    required String sellerId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.productsCollectionId,
      token: token,
      filter: {'sellerId': sellerId},
      limit: 200,
    );
    return docs.map(Product.fromJson).toList();
  }

  Future<Product> create({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final doc = await _dataService.create(EnvConfig.productsCollectionId, body,
        token: token);
    return Product.fromJson(doc);
  }

  Future<Product> update({
    required String token,
    required String id,
    required Map<String, dynamic> body,
  }) async {
    final doc = await _dataService.update(
      EnvConfig.productsCollectionId,
      id,
      body,
      token: token,
    );
    return Product.fromJson(doc);
  }
}
