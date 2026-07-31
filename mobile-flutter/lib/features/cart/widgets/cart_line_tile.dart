import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/cart.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    super.key,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl == null
                  ? ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.image_outlined,
                          color: colorScheme.onSurfaceVariant),
                    )
                  : CachedNetworkImage(
                      imageUrl: item.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(item.priceCents, item.currency),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      onPressed: () => onQuantityChanged(item.quantity - 1),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _StepperButton(
                      icon: Icons.add,
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline),
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(item.lineTotalCents, item.currency),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
