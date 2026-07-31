import 'package:flutter/material.dart';

import '../../../models/order.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (MaterialColor color, IconData icon) = switch (status) {
      OrderStatus.pending => (Colors.grey, Icons.hourglass_empty),
      OrderStatus.awaitingPayment => (Colors.orange, Icons.schedule),
      OrderStatus.paid => (Colors.blue, Icons.check_circle_outline),
      OrderStatus.shipped => (Colors.indigo, Icons.local_shipping_outlined),
      OrderStatus.delivered => (Colors.green, Icons.task_alt),
      OrderStatus.cancelled => (Colors.red, Icons.cancel_outlined),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color.shade700),
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
