import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_providers.dart';
import '../../models/payment_link.dart';

/// Polls `GET /api/payment-links/:token` every 4 seconds - a public,
/// unauthenticated read - until the link reaches a terminal status (`paid`,
/// `expired`, `cancelled`), mirroring the web app's `usePaymentLinkStatus`.
/// A transient network failure keeps polling instead of surfacing a hard
/// error immediately; five consecutive failures give up and let the screen
/// show a retry action.
final paymentLinkStatusProvider =
    StreamProvider.autoDispose.family<PaymentLink, String>((ref, token) async* {
  final service = ref.watch(checkoutProxyServiceProvider);
  const pollInterval = Duration(seconds: 4);
  const maxConsecutiveFailures = 5;
  var consecutiveFailures = 0;

  while (true) {
    try {
      final link = await service.getPaymentLinkStatus(token);
      consecutiveFailures = 0;
      yield link;
      if (link.status.isTerminal) return;
    } on Exception {
      consecutiveFailures++;
      if (consecutiveFailures >= maxConsecutiveFailures) rethrow;
    }
    await Future<void>.delayed(pollInterval);
  }
});
