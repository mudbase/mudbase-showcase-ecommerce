import '../../config/env_config.dart';
import '../../core/json_field.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/cart.dart';

/// One `carts` document per user, ownership-scoped (`customer` role,
/// `{userId: "$userId"}`). Mudbase has no native upsert endpoint, so every
/// write reads the existing document first and creates only if one doesn't
/// exist yet - mirrors the web app's `useCart`/`migrateGuestCartToServer`
/// read-then-create-or-update pattern (see README "Known limitations").
class CartRepository {
  const CartRepository(this._dataService);

  final MudbaseDataService _dataService;

  Future<Cart?> getForUser(
      {required String token, required String userId}) async {
    final docs = await _dataService.list(
      EnvConfig.cartsCollectionId,
      token: token,
      filter: {'userId': userId},
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return Cart.fromJson(docs.first);
  }

  Future<Cart> save({
    required String token,
    required String userId,
    required List<CartItem> items,
  }) async {
    final itemsJson =
        stringifyJsonField(items.map((item) => item.toJson()).toList());
    final existing = await getForUser(token: token, userId: userId);
    if (existing != null) {
      final doc = await _dataService.update(
        EnvConfig.cartsCollectionId,
        existing.id,
        {'itemsJson': itemsJson},
        token: token,
      );
      return Cart.fromJson(doc);
    }
    final doc = await _dataService.create(
      EnvConfig.cartsCollectionId,
      {'userId': userId, 'itemsJson': itemsJson},
      token: token,
    );
    return Cart.fromJson(doc);
  }
}
