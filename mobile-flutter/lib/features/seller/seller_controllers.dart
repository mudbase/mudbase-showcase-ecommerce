import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../auth/auth_controller.dart';

/// The seller fulfillment queue - unrestricted read across every order
/// (`seller` role has unconditional read/update on `orders`), matching the
/// web app's `SellerOrderQueue`. This app uses pull-to-refresh instead of
/// the web app's Socket.IO realtime subscription - see README "Known
/// limitations" for why.
final sellerOrdersProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repository = ref.watch(orderRepositoryProvider);
  final orders = await authNotifier
      .callAuthorized((token) => repository.listAll(token: token));
  return orders..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final sellerProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return const [];
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repository = ref.watch(productRepositoryProvider);
  return authNotifier.callAuthorized(
    (token) => repository.listForSeller(token: token, sellerId: user.id),
  );
});

final sellerProductByIdProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, id) async {
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repository = ref.watch(productRepositoryProvider);
  return authNotifier
      .callAuthorized((token) => repository.getById(token: token, id: id));
});

final sellerOrderActionsProvider = Provider<SellerOrderActions>((ref) {
  return SellerOrderActions(ref);
});

/// The seller queue's single "advance" action - mirrors the web app's
/// `NEXT_STATUS` map (`paid` -> `shipped` -> `delivered`). Any other status
/// has no manual forward action from this screen.
class SellerOrderActions {
  const SellerOrderActions(this._ref);

  final Ref _ref;

  Future<void> advance(Order order) async {
    final next = order.orderStatus.nextFulfillmentStatus;
    if (next == null) return;
    final authNotifier = _ref.read(authControllerProvider.notifier);
    final repository = _ref.read(orderRepositoryProvider);
    await authNotifier.callAuthorized(
      (token) =>
          repository.updateStatus(token: token, id: order.id, status: next),
    );
    _ref.invalidate(sellerOrdersProvider);
  }
}
