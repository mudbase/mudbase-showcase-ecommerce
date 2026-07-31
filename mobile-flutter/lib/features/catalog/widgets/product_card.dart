import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentOff =
        discountPercent(product.priceCents, product.compareAtPriceCents);
    final imageUrl = product.images.isNotEmpty ? product.images.first : null;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl == null
                        ? _ImagePlaceholder(colorScheme: colorScheme)
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                _ImagePlaceholder(colorScheme: colorScheme),
                            errorWidget: (context, url, error) =>
                                _ImagePlaceholder(colorScheme: colorScheme),
                          ),
                  ),
                  if (percentOff != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        label: '$percentOff% off',
                        color: colorScheme.error,
                        onColor: colorScheme.onError,
                      ),
                    ),
                  if (!product.inStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        label: 'Out of stock',
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        onColor: colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatMoney(product.priceCents, product.currency),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (percentOff != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatMoney(
                            product.compareAtPriceCents ?? product.priceCents,
                            product.currency,
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        size: 32,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.label, required this.color, required this.onColor});

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
