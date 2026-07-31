import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_exception.dart';
import '../../models/cart.dart';
import '../../widgets/async_value_view.dart';
import '../cart/cart_controller.dart';
import 'catalog_controller.dart';
import 'widgets/image_gallery.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productBySlugProvider(widget.slug));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: AsyncValueView(
        value: productAsync,
        onRetry: () => ref.invalidate(productBySlugProvider(widget.slug)),
        data: (context, product) {
          if (product == null) {
            return Center(
              child: Text(
                "This product isn't available anymore.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final percentOff =
              discountPercent(product.priceCents, product.compareAtPriceCents);
          final colorScheme = Theme.of(context).colorScheme;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImageGallery(images: product.images),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          if (product.category != null &&
                              product.category!.isNotEmpty)
                            Chip(label: Text(product.category!)),
                          if (percentOff != null)
                            Chip(
                              label: Text('$percentOff% off'),
                              backgroundColor: colorScheme.errorContainer,
                              labelStyle: TextStyle(
                                  color: colorScheme.onErrorContainer),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatMoney(product.priceCents, product.currency),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (percentOff != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(
                                product.compareAtPriceCents ??
                                    product.priceCents,
                                product.currency,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          product.description!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        product.inStock
                            ? '${product.stock} in stock'
                            : 'Currently out of stock',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (product.inStock) ...[
                        Row(
                          children: [
                            _QuantityStepper(
                              quantity: _quantity,
                              max: product.stock,
                              onChanged: (value) =>
                                  setState(() => _quantity = value),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _adding
                                    ? null
                                    : () => _addToCart(
                                        context,
                                        product.id,
                                        product.name,
                                        product.priceCents,
                                        product.currency,
                                        product.imageUrl),
                                child: _adding
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Add to cart'),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    String productId,
    String name,
    int priceCents,
    String currency,
    String? imageUrl,
  ) async {
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(cartControllerProvider.notifier).addItem(
            CartItem(
              productId: productId,
              name: name,
              priceCents: priceCents,
              currency: currency,
              imageUrl: imageUrl,
              quantity: _quantity,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text('Added $name to cart')));
    } on MudbaseException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper(
      {required this.quantity, required this.max, required this.onChanged});

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
