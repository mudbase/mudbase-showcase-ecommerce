import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/empty_state.dart';
import 'catalog_controller.dart';
import 'widgets/product_card.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(catalogFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(filteredProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(allActiveProductsProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: (value) =>
                      ref.read(catalogFilterProvider.notifier).setSearch(value),
                  decoration: const InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
            ),
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ChoiceChip(
                          label: const Text('All'),
                          selected: filter.category == null,
                          onSelected: (_) => ref
                              .read(catalogFilterProvider.notifier)
                              .setCategory(null),
                        );
                      }
                      final category = categories[index - 1];
                      return ChoiceChip(
                        label: Text(category),
                        selected: filter.category == category,
                        onSelected: (_) => ref
                            .read(catalogFilterProvider.notifier)
                            .setCategory(category),
                      );
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: AsyncValueSliver(
                value: productsAsync,
                onRetry: () => ref.invalidate(allActiveProductsProvider),
                builder: (context, products) {
                  if (products.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.storefront_outlined,
                        message: 'No products match right now.',
                      ),
                    );
                  }
                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => context.push('/product/${product.slug}'),
                        );
                      },
                      childCount: products.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sliver-compatible counterpart to [AsyncValueView] - `CustomScrollView`
/// requires every child to be a sliver, and `SliverToBoxAdapter`-wrapping a
/// box-based loading/error view would break the grid layout below it.
class AsyncValueSliver<T> extends StatelessWidget {
  const AsyncValueSliver({
    required this.value,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => builder(context, data),
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.error_outline,
          message: error.toString(),
          action: onRetry == null
              ? null
              : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ),
    );
  }
}
