import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/payment_link.dart';
import '../../widgets/async_value_view.dart';
import 'payment_status_controller.dart';

class PaymentStatusScreen extends ConsumerWidget {
  const PaymentStatusScreen({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkAsync = ref.watch(paymentLinkStatusProvider(token));

    return Scaffold(
      appBar: AppBar(title: const Text('Pay for your order')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: AsyncValueView(
          value: linkAsync,
          onRetry: () => ref.invalidate(paymentLinkStatusProvider(token)),
          data: (context, link) => _PaymentLinkPanel(
            link: link,
            onDone: () => context.go('/orders'),
          ),
        ),
      ),
    );
  }
}

class _PaymentLinkPanel extends StatelessWidget {
  const _PaymentLinkPanel({required this.link, required this.onDone});

  final PaymentLink link;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment status',
                    style: Theme.of(context).textTheme.titleMedium),
                _StatusChip(status: link.status),
              ],
            ),
            const SizedBox(height: 20),
            switch (link.status) {
              PaymentLinkStatus.paid => _StatusMessage(
                  icon: Icons.check_circle,
                  color: Colors.green.shade600,
                  message: 'Payment received — thank you!',
                ),
              PaymentLinkStatus.expired ||
              PaymentLinkStatus.cancelled =>
                _StatusMessage(
                  icon: Icons.cancel_outlined,
                  color: colorScheme.error,
                  message: 'This payment link is no longer active.',
                ),
              PaymentLinkStatus.pending => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waiting for payment — this screen updates automatically.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                        label: 'Amount',
                        value: '${link.amount ?? '-'} ${link.currency}'),
                    _DetailRow(label: 'Network', value: link.network),
                    _DetailRow(
                        label: 'Send to', value: link.address, mono: true),
                  ],
                ),
            },
            const SizedBox(height: 20),
            if (link.status.isTerminal)
              OutlinedButton(
                  onPressed: onDone, child: const Text('View my orders')),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage(
      {required this.icon, required this.color, required this.message});

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PaymentLinkStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, MaterialColor color) = switch (status) {
      PaymentLinkStatus.paid => ('Paid', Colors.green),
      PaymentLinkStatus.expired => ('Expired', Colors.red),
      PaymentLinkStatus.cancelled => ('Cancelled', Colors.red),
      PaymentLinkStatus.pending => ('Pending', Colors.orange),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color.shade700),
      visualDensity: VisualDensity.compact,
    );
  }
}
