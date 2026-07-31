import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_exception.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import 'cart_controller.dart';
import 'widgets/cart_line_tile.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartControllerProvider);
    final subtotalCents = ref.watch(cartSubtotalCentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: AsyncValueView(
        value: cartAsync,
        onRetry: () => ref.invalidate(cartControllerProvider),
        data: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'Your cart is empty — add something from the catalog.',
            );
          }
          final currency = items.first.currency;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CartLineTile(
                      item: item,
                      onQuantityChanged: (quantity) => _updateQuantity(
                        context,
                        ref,
                        item.productId,
                        quantity,
                      ),
                      onRemove: () => _removeItem(context, ref, item.productId),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            formatMoney(subtotalCents, currency),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.push('/checkout'),
                        child: const Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    String productId,
    int quantity,
  ) async {
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateQuantity(productId, quantity);
    } on MudbaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeItem(
      BuildContext context, WidgetRef ref, String productId) async {
    try {
      await ref.read(cartControllerProvider.notifier).removeItem(productId);
    } on MudbaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
