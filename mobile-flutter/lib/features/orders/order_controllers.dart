import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/order.dart';
import '../auth/auth_controller.dart';

final ownOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) return const [];
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repository = ref.watch(orderRepositoryProvider);
  final orders = await authNotifier.callAuthorized(
    (token) => repository.listOwn(token: token, userId: user.id),
  );
  return orders..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final orderByIdProvider =
    FutureProvider.autoDispose.family<Order?, String>((ref, id) async {
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repository = ref.watch(orderRepositoryProvider);
  return authNotifier
      .callAuthorized((token) => repository.getById(token: token, id: id));
});
