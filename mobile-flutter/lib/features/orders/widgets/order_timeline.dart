import 'package:flutter/material.dart';

import '../../../models/order.dart';

const List<OrderStatus> _timelineSteps = [
  OrderStatus.awaitingPayment,
  OrderStatus.paid,
  OrderStatus.shipped,
  OrderStatus.delivered,
];

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_outlined,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          const Text('This order was cancelled.'),
        ],
      );
    }

    final currentIndex = _timelineSteps.indexOf(status);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < _timelineSteps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= currentIndex
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                ),
                child: i <= currentIndex
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                _timelineSteps[i].label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
