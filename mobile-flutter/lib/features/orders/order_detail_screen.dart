import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../widgets/async_value_view.dart';
import 'order_controllers.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/order_timeline.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: AsyncValueView(
        value: orderAsync,
        onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
        data: (context, order) {
          if (order == null) {
            return const Center(child: Text("This order couldn't be found."));
          }
          final address = order.shippingAddress;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${shortOrderId(order.id)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          formatDate(order.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    OrderStatusBadge(status: order.orderStatus),
                  ],
                ),
                const SizedBox(height: 20),
                OrderTimeline(status: order.orderStatus),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('${item.name} × ${item.quantity}')),
                        Text(formatMoney(
                            item.priceCents * item.quantity, order.currency)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      formatMoney(order.subtotalCents, order.currency),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (address != null) ...[
                  const SizedBox(height: 24),
                  Text('Shipping to',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    [
                      address.fullName,
                      if (address.line2 != null)
                        '${address.line1}, ${address.line2}'
                      else
                        address.line1,
                      '${address.city}, ${address.region} ${address.postalCode}',
                      address.country,
                    ].join('\n'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (order.needsPayment) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context
                        .push('/checkout/status/${order.paymentLinkToken}'),
                    child: const Text('Complete payment'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
