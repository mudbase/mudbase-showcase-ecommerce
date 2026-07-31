import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env_config.dart';
import '../../core/checkout_proxy_service.dart';
import '../../core/json_field.dart';
import '../../core/service_providers.dart';
import '../../data/repository_providers.dart';
import '../../models/order.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';

sealed class PlaceOrderOutcome {
  const PlaceOrderOutcome();
}

class PlaceOrderSuccess extends PlaceOrderOutcome {
  const PlaceOrderSuccess(this.paymentLinkToken);
  final String paymentLinkToken;
}

/// The org's Payment Links require KYC approval, re-checked live on every
/// creation call - this is a real, expected state (see
/// `checkout_proxy_service.dart`), not an error to hide.
class PlaceOrderNeedsVerification extends PlaceOrderOutcome {
  const PlaceOrderNeedsVerification(this.message);
  final String message;
}

class PlaceOrderFailed extends PlaceOrderOutcome {
  const PlaceOrderFailed(this.message);
  final String message;
}

final checkoutControllerProvider = Provider<CheckoutController>((ref) {
  return CheckoutController(ref);
});

/// Orchestrates the full checkout flow: create the `orders` document as the
/// signed-in customer, then delegate Payment Link creation to the deployed
/// web app's proxy (see `core/checkout_proxy_service.dart` for why). Cart
/// clearing only happens once the payment link is actually created, so a
/// failed checkout leaves the cart intact for retry.
class CheckoutController {
  CheckoutController(this._ref);

  final Ref _ref;

  Future<PlaceOrderOutcome> placeOrder(
      {required ShippingAddress address}) async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    if (user == null) {
      return const PlaceOrderFailed('You must be signed in to check out.');
    }
    final items = _ref.read(cartControllerProvider).valueOrNull ?? const [];
    if (items.isEmpty) {
      return const PlaceOrderFailed('Your cart is empty.');
    }

    final token = _ref.read(authControllerProvider.notifier).requireToken();
    final orderRepository = _ref.read(orderRepositoryProvider);
    final subtotalCents =
        items.fold<int>(0, (sum, item) => sum + item.lineTotalCents);

    final order = await orderRepository.create(
      token: token,
      body: {
        'userId': user.id,
        'itemsJson': stringifyJsonField(
          items
              .map((item) => OrderLineItem(
                    productId: item.productId,
                    name: item.name,
                    priceCents: item.priceCents,
                    quantity: item.quantity,
                  ).toJson())
              .toList(),
        ),
        'subtotalCents': subtotalCents,
        'currency': 'USD',
        'orderStatus': OrderStatus.awaitingPayment.wireValue,
        'shippingName': address.fullName,
        'shippingAddressJson': stringifyJsonField(address.toJson()),
        'paymentStatus': OrderPaymentStatus.unpaid.wireValue,
      },
    );

    final checkoutProxy = _ref.read(checkoutProxyServiceProvider);
    final amount = (subtotalCents / 100).toStringAsFixed(2);
    // Informational metadata on the Payment Link only - this native app
    // polls `GET /api/payment-links/:token` directly for status rather than
    // following a browser redirect, so nothing in this app ever navigates
    // to this URL. Reusing the web app's own `/orders/:id` page keeps the
    // link meaningful for anyone who opens it outside the app.
    final redirectUrl = '${EnvConfig.checkoutProxyBaseUrl}/orders/${order.id}';

    final result = await checkoutProxy.createPaymentLink(
      orderId: order.id,
      amount: amount,
      currency: 'USDC',
      network: 'POLYGON',
      redirectUrl: redirectUrl,
    );

    if (result is CheckoutPayLinkSuccess) {
      await orderRepository.update(
        token: token,
        id: order.id,
        body: {'paymentLinkToken': result.token},
      );
      await _ref.read(cartControllerProvider.notifier).clear();
      return PlaceOrderSuccess(result.token);
    }

    final failure = result as CheckoutPayLinkFailure;
    if (failure.isKycRequired) {
      await orderRepository.update(
        token: token,
        id: order.id,
        body: {'orderStatus': OrderStatus.pending.wireValue},
      );
      return PlaceOrderNeedsVerification(failure.message);
    }
    return PlaceOrderFailed(failure.message);
  }
}
