import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/product.dart';
import '../auth/auth_controller.dart';

class CatalogFilter {
  const CatalogFilter({this.category, this.search = ''});

  final String? category;
  final String search;

  CatalogFilter copyWith(
      {String? category, bool clearCategory = false, String? search}) {
    return CatalogFilter(
      category: clearCategory ? null : (category ?? this.category),
      search: search ?? this.search,
    );
  }
}

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setCategory(String? category) {
    state = state.copyWith(category: category, clearCategory: category == null);
  }

  void setSearch(String value) => state = state.copyWith(search: value);
}

final catalogFilterProvider =
    NotifierProvider<CatalogFilterController, CatalogFilter>(
        CatalogFilterController.new);

/// One fetch of every active product for the signed-in session; category
/// and search filtering both happen client-side against this cached list
/// (see [filteredProductsProvider]) so switching a category chip or typing
/// a search query never re-hits the network.
final allActiveProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return const [];
  final token = ref.read(authControllerProvider.notifier).requireToken();
  final repository = ref.watch(productRepositoryProvider);
  return repository.listActive(token: token);
});

final categoriesProvider = Provider.autoDispose<List<String>>((ref) {
  final products = ref.watch(allActiveProductsProvider).valueOrNull ?? const [];
  final categories = products
      .map((product) => product.category)
      .whereType<String>()
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return categories;
});

final filteredProductsProvider =
    Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(catalogFilterProvider);
  final productsAsync = ref.watch(allActiveProductsProvider);
  return productsAsync.whenData((products) {
    var result = products;
    final category = filter.category;
    if (category != null) {
      result = result.where((product) => product.category == category).toList();
    }
    final query = filter.search.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    }
    return result;
  });
});

final productBySlugProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, slug) async {
  final token = ref.read(authControllerProvider.notifier).requireToken();
  final repository = ref.watch(productRepositoryProvider);
  return repository.getBySlug(token: token, slug: slug);
});
