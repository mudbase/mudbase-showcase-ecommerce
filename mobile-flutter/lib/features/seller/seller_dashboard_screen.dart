import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_exception.dart';
import '../../models/order.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../account/account_screen.dart';
import '../orders/widgets/order_status_badge.dart';
import 'seller_controllers.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seller dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Orders'),
              Tab(text: 'Products'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Account',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                if (tabController.index != 1) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  onPressed: () => context.push('/seller/products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                );
              },
            );
          },
        ),
        body: const TabBarView(
          children: [_SellerOrdersTab(), _SellerProductsTab()],
        ),
      ),
    );
  }
}

class _SellerOrdersTab extends ConsumerWidget {
  const _SellerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return AsyncValueView(
      value: ordersAsync,
      onRetry: () => ref.invalidate(sellerOrdersProvider),
      data: (context, orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            message:
                "No orders yet — they'll appear here the instant one comes in.",
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(sellerOrdersProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              final nextStatus = order.orderStatus.nextFulfillmentStatus;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${shortOrderId(order.id)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${order.shippingName ?? 'Customer'} · ${formatDate(order.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatMoney(order.subtotalCents, order.currency),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OrderStatusBadge(status: order.orderStatus),
                          if (nextStatus != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _advance(context, ref, order),
                              child: Text(
                                  'Mark ${nextStatus.label.toLowerCase()}'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _advance(
      BuildContext context, WidgetRef ref, Order order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sellerOrderActionsProvider).advance(order);
    } on MudbaseException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SellerProductsTab extends ConsumerWidget {
  const _SellerProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(sellerProductsProvider);

    return AsyncValueView(
      value: productsAsync,
      onRetry: () => ref.invalidate(sellerProductsProvider),
      data: (context, products) {
        if (products.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'No products yet — add your first one.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(sellerProductsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                child: ListTile(
                  onTap: () =>
                      context.push('/seller/products/${product.id}/edit'),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: product.imageUrl == null
                        ? null
                        : NetworkImage(product.imageUrl!),
                    child: product.imageUrl == null
                        ? const Icon(Icons.inventory_2_outlined)
                        : null,
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    '${formatMoney(product.priceCents, product.currency)} · '
                    '${product.stock} in stock'
                    '${product.isActive ? '' : ' · hidden'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
