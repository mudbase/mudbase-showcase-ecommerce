import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/order.dart';

class OrderRepository {
  const OrderRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// A customer's own order history - server-enforced ownership scope
  /// (`customer` role, `{userId: "$userId"}`) means this filter is UX
  /// convenience, not the real security boundary.
  Future<List<Order>> listOwn({
    required String token,
    required String userId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.ordersCollectionId,
      token: token,
      filter: {'userId': userId},
      limit: 100,
    );
    return docs.map(Order.fromJson).toList();
  }

  /// The seller fulfillment queue - unrestricted read across every
  /// customer's orders (`seller` role has unconditional read/update on
  /// `orders`, per the collection's permission shape).
  Future<List<Order>> listAll({required String token}) async {
    final docs = await _dataService.list(
      EnvConfig.ordersCollectionId,
      token: token,
      limit: 100,
    );
    return docs.map(Order.fromJson).toList();
  }

  Future<Order?> getById({required String token, required String id}) async {
    final doc = await _dataService.getById(EnvConfig.ordersCollectionId, id,
        token: token);
    return doc == null ? null : Order.fromJson(doc);
  }

  Future<Order> create({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final doc = await _dataService.create(EnvConfig.ordersCollectionId, body,
        token: token);
    return Order.fromJson(doc);
  }

  Future<Order> update({
    required String token,
    required String id,
    required Map<String, dynamic> body,
  }) async {
    final doc = await _dataService.update(
      EnvConfig.ordersCollectionId,
      id,
      body,
      token: token,
    );
    return Order.fromJson(doc);
  }

  Future<void> updateStatus({
    required String token,
    required String id,
    required OrderStatus status,
  }) async {
    await _dataService.update(
      EnvConfig.ordersCollectionId,
      id,
      {'orderStatus': status.wireValue},
      token: token,
    );
  }
}
