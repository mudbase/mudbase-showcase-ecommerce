import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/cart.dart';
import '../auth/auth_controller.dart';

/// The signed-in customer's cart, held as a flat `List<CartItem>` (the
/// document wrapper - `_id`, `userId` - is an implementation detail the rest
/// of the app never needs). Every mutation is optimistic: applied to local
/// state immediately, persisted to the `carts` collection, and rolled back
/// with the mutation's exception rethrown to the caller if the write fails
/// - so a screen can show a snackbar without the cart silently reverting
/// invisibly or a full error screen replacing the cart contents.
class CartController extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const [];
    final token = ref.read(authControllerProvider.notifier).requireToken();
    final repository = ref.read(cartRepositoryProvider);
    final cart = await repository.getForUser(token: token, userId: user.id);
    return cart?.items ?? const [];
  }

  Future<void> addItem(CartItem item) {
    return _mutate((current) {
      final next = [...current];
      final index = next.indexWhere((i) => i.productId == item.productId);
      if (index >= 0) {
        next[index] = next[index]
            .copyWith(quantity: next[index].quantity + item.quantity);
      } else {
        next.add(item);
      }
      return next;
    });
  }

  Future<void> updateQuantity(String productId, int quantity) {
    return _mutate((current) {
      if (quantity <= 0) {
        return current.where((i) => i.productId != productId).toList();
      }
      return current
          .map((i) =>
              i.productId == productId ? i.copyWith(quantity: quantity) : i)
          .toList();
    });
  }

  Future<void> removeItem(String productId) {
    return _mutate(
        (current) => current.where((i) => i.productId != productId).toList());
  }

  Future<void> clear() => _mutate((_) => const []);

  Future<void> _mutate(
    List<CartItem> Function(List<CartItem> current) transform,
  ) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    final previous = state.valueOrNull ?? const <CartItem>[];
    final optimistic = transform(previous);
    state = AsyncData(optimistic);

    final token = ref.read(authControllerProvider.notifier).requireToken();
    final repository = ref.read(cartRepositoryProvider);
    try {
      final cart = await repository.save(
          token: token, userId: user.id, items: optimistic);
      state = AsyncData(cart.items);
    } on Exception {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final cartControllerProvider =
    AsyncNotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartSubtotalCentsProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(cartControllerProvider).valueOrNull ?? const [];
  return items.fold<int>(0, (sum, item) => sum + item.lineTotalCents);
});

final cartItemCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(cartControllerProvider).valueOrNull ?? const [];
  return items.fold<int>(0, (sum, item) => sum + item.quantity);
});
