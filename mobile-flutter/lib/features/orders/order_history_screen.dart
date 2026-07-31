import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import 'order_controllers.dart';
import 'widgets/order_status_badge.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ownOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: AsyncValueView(
        value: ordersAsync,
        onRetry: () => ref.invalidate(ownOrdersProvider),
        data: (context, orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: "You haven't placed any orders yet.",
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(ownOrdersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/orders/${order.id}'),
                    title: Text('Order #${shortOrderId(order.id)}'),
                    subtitle: Text(formatDate(order.createdAt)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMoney(order.subtotalCents, order.currency),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        OrderStatusBadge(status: order.orderStatus),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
