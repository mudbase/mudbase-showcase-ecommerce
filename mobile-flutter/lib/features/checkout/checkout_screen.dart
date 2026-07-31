import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_exception.dart';
import '../../models/order.dart';
import '../../widgets/empty_state.dart';
import '../cart/cart_controller.dart';
import 'checkout_controller.dart';
import 'widgets/shipping_form.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _placeOrder(ShippingAddress address) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final outcome = await ref
          .read(checkoutControllerProvider)
          .placeOrder(address: address);
      if (!mounted) return;
      switch (outcome) {
        case PlaceOrderSuccess(:final paymentLinkToken):
          context.pushReplacement('/checkout/status/$paymentLinkToken');
        case PlaceOrderNeedsVerification(:final message):
          setState(() => _errorMessage = message);
        case PlaceOrderFailed(:final message):
          setState(() => _errorMessage = message);
      }
    } on MudbaseException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartControllerProvider).valueOrNull ?? const [];
    final subtotalCents = ref.watch(cartSubtotalCentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cartItems.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              message:
                  'Your cart is empty — add something before checking out.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order summary',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          ...cartItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child:
                                        Text('${item.name} × ${item.quantity}'),
                                  ),
                                  Text(formatMoney(
                                      item.lineTotalCents, item.currency)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                formatMoney(
                                    subtotalCents, cartItems.first.currency),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  ShippingForm(onSubmit: _placeOrder, submitting: _submitting),
                ],
              ),
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
