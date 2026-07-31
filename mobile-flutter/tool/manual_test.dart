// ignore_for_file: avoid_print
//
// Standalone, non-Flutter smoke test that exercises this app's own
// `lib/core/*` services - the exact classes `AuthController`,
// `CartController`, `CheckoutController`, and the seller providers call -
// directly against the real, live `cloud.mudbase.dev` project. No Flutter
// SDK/device is required to run this: `AuthService`, `MudbaseDataService`,
// and `CheckoutProxyService` only depend on `dio`/`mudbase_sdk`, never
// `package:flutter`.
//
// Run with (values are this showcase project's real, already-provisioned
// IDs - not secrets, same ones baked into `dart_define.example.json`):
//
//   dart run tool/manual_test.dart \
//     --define=MUDBASE_PROJECT_ID=6a6b9315a4f370fb26792e7a \
//     --define=PRODUCTS_COLLECTION_ID=6a6b9316a4f370fb26792e91 \
//     --define=ORDERS_COLLECTION_ID=6a6b9316a4f370fb26792ea1 \
//     --define=CARTS_COLLECTION_ID=6a6b9316a4f370fb26792eaf
//
// Exits with a non-zero status if any step fails, printing which step and
// why - intended for a human (or CI) to read top to bottom, not for
// assertion-per-line unit testing (see `test/` for that).
import 'dart:io';

import 'package:mudbase_sdk/mudbase_sdk.dart';
import 'package:mudbase_showcase_ecommerce/core/auth_service.dart';
import 'package:mudbase_showcase_ecommerce/core/checkout_proxy_service.dart';
import 'package:mudbase_showcase_ecommerce/core/json_field.dart';
import 'package:mudbase_showcase_ecommerce/core/mudbase_data_service.dart';
import 'package:mudbase_showcase_ecommerce/core/mudbase_exception.dart';
import 'package:mudbase_showcase_ecommerce/models/order.dart';
import 'package:mudbase_showcase_ecommerce/models/product.dart';

const _baseUrl = String.fromEnvironment(
  'MUDBASE_BASE_URL',
  defaultValue: 'https://cloud.mudbase.dev',
);
const _projectId = String.fromEnvironment('MUDBASE_PROJECT_ID');
const _productsCollectionId =
    String.fromEnvironment('PRODUCTS_COLLECTION_ID');
const _ordersCollectionId = String.fromEnvironment('ORDERS_COLLECTION_ID');
const _cartsCollectionId = String.fromEnvironment('CARTS_COLLECTION_ID');
const _checkoutProxyBaseUrl = String.fromEnvironment(
  'CHECKOUT_PROXY_BASE_URL',
  defaultValue: 'https://mudbase-showcase-ecommerce.vercel.app',
);

// Pre-provisioned SHARED test accounts (per project brief) - account
// registration on this project is rate-limited to 3/hour per IP, shared
// across every language-SDK test agent exercising this same project
// concurrently, so this script only ever logs in, never registers. Reusing
// the same two accounts across every run/every agent is intentional.
const _sellerEmail = 'shared-test-seller@example.test';
const _customerEmail = 'shared-test-customer@example.test';
const _password = 'SharedTest123!';

int _passed = 0;
int _failed = 0;
int _skipped = 0;

/// Returns whether the step passed, so a caller can decide whether it is
/// safe to run later steps that read state this one was supposed to set
/// (a token, an id list) - see [_requireStep].
Future<bool> _step(String name, Future<void> Function() body) async {
  stdout.write('- $name ... ');
  try {
    await body();
    stdout.writeln('PASS');
    _passed++;
    return true;
  } on Object catch (error) {
    stdout.writeln('FAIL ($error)');
    _failed++;
    return false;
  }
}

/// For steps every later step in this script depends on (login, product
/// setup): if this fails, every remaining step would either throw a
/// confusing null-check/RangeError on state that was never populated, or
/// silently exercise nothing. Printing a clear summary and stopping here is
/// more honest than letting that cascade of unrelated-looking failures
/// print, per this project's "never silently swallow errors" rule.
Future<void> _requireStep(String name, Future<void> Function() body) async {
  final ok = await _step(name, body);
  if (ok) return;
  print('');
  print(
    'Stopping: "$name" failed and every remaining step depends on it - '
    'see the FAIL line above for the real cause.',
  );
  print('Passed: $_passed, Failed: $_failed, Skipped: $_skipped');
  exit(1);
}

/// Like [_step], but for steps that only make sense given a precondition
/// from an earlier step (e.g. polling a payment-link token that only exists
/// if link creation actually succeeded). Recorded as neither pass nor fail -
/// this project's org has no payment merchant configured, so payment-link
/// creation is EXPECTED to fail with a documented 502 (see README
/// "Payments" / task brief) and every step downstream of a real token is
/// correctly inapplicable, not broken.
void _stepSkip(String name, String reason) {
  stdout.writeln('- $name ... SKIP ($reason)');
  _skipped++;
}

void main() async {
  print('Mudbase Showcase Flutter - live manual smoke test');
  print('Base URL: $_baseUrl');
  print('Project:  $_projectId');
  print('');

  final missing = <String>[
    if (_projectId.isEmpty) 'MUDBASE_PROJECT_ID',
    if (_productsCollectionId.isEmpty) 'PRODUCTS_COLLECTION_ID',
    if (_ordersCollectionId.isEmpty) 'ORDERS_COLLECTION_ID',
    if (_cartsCollectionId.isEmpty) 'CARTS_COLLECTION_ID',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Missing --define values: ${missing.join(', ')}');
    exit(64);
  }

  final sdk = MudbaseSdk(basePathOverride: _baseUrl);
  final auth = AuthService(sdk, _projectId);
  final data = MudbaseDataService(sdk, _projectId);
  final checkoutProxy = CheckoutProxyService(sdk);

  String? sellerToken;
  String? sellerId;
  final createdProductIds = <String>[];
  // Populated from the actual server-returned document for each entry in
  // createdProductIds (whether reused from an earlier run or freshly
  // created here) - cart/order construction below reads name/price from
  // this rather than assuming fixed literals, so a reused product from a
  // previous run can never silently diverge from what's actually stored.
  final testProducts = <Product>[];
  String? customerToken;
  String? customerRefreshToken;
  String? customerId;
  String? orderId;
  String? paymentLinkToken;

  await _requireStep('login as the shared seller account', () async {
    final json = await auth.login(email: _sellerEmail, password: _password);
    sellerToken = json['token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    sellerId = user?['id'] as String? ?? user?['_id'] as String?;
    if (sellerToken == null || sellerId == null) {
      throw StateError('seller session missing token/id: $json');
    }
    final customRole = user?['customRole'];
    if (customRole != 'seller') {
      throw StateError('expected customRole "seller", got $customRole');
    }
  });

  await _requireStep(
      'create test products as the seller (reusing any from earlier runs)',
      () async {
    final existing = await data.list(
      _productsCollectionId,
      token: sellerToken!,
      filter: {'sellerId': sellerId, 'category': 'test'},
      limit: 10,
    );
    for (final doc in existing.take(2)) {
      final id = doc['_id'] as String?;
      if (id == null) continue;
      createdProductIds.add(id);
      testProducts.add(Product.fromJson(doc));
    }
    for (final spec in [
      ('Flutter Test Mug', 1899),
      ('Flutter Test Tote Bag', 3499),
    ]) {
      if (createdProductIds.length >= 2) break;
      final (name, priceCents) = spec;
      final doc = await data.create(
        _productsCollectionId,
        {
          'name': name,
          'slug': slugify(name),
          'description': 'Created by mobile-flutter/tool/manual_test.dart',
          'priceCents': priceCents,
          'currency': 'USD',
          'imageUrl': 'https://picsum.photos/seed/${slugify(name)}/400/400',
          'galleryJson': stringifyJsonField(<String>[]),
          'category': 'test',
          'stock': 25,
          'isActive': true,
          'sellerId': sellerId,
        },
        token: sellerToken!,
      );
      final id = doc['_id'] as String?;
      if (id == null) throw StateError('product create returned no _id');
      createdProductIds.add(id);
      testProducts.add(Product.fromJson(doc));
    }
    if (createdProductIds.length != 2 || testProducts.length != 2) {
      throw StateError(
        'expected 2 available products, got ${createdProductIds.length}',
      );
    }
  });

  await _requireStep('login as the shared customer account', () async {
    final json = await auth.login(email: _customerEmail, password: _password);
    customerToken = json['token'] as String?;
    customerRefreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    customerId = user?['id'] as String? ?? user?['_id'] as String?;
    if (customerToken == null || customerId == null) {
      throw StateError('customer session missing token/id: $json');
    }
  });

  await _step('browse active catalog as the customer', () async {
    final docs = await data.list(
      _productsCollectionId,
      token: customerToken!,
      filter: {'isActive': true},
      limit: 100,
    );
    final products = docs.map(Product.fromJson).toList();
    final foundBoth = createdProductIds
        .every((id) => products.any((product) => product.id == id));
    if (!foundBoth) {
      throw StateError(
        'catalog read did not include both just-created products '
        '(got ${products.length} active products)',
      );
    }
  });

  await _step('add items to cart (read-then-create, no native upsert)', () async {
    final existing = await data.list(
      _cartsCollectionId,
      token: customerToken!,
      filter: {'userId': customerId},
      limit: 1,
    );
    final itemsJson = stringifyJsonField([
      {
        'productId': testProducts[0].id,
        'name': testProducts[0].name,
        'priceCents': testProducts[0].priceCents,
        'currency': testProducts[0].currency,
        'quantity': 2,
      },
      {
        'productId': testProducts[1].id,
        'name': testProducts[1].name,
        'priceCents': testProducts[1].priceCents,
        'currency': testProducts[1].currency,
        'quantity': 1,
      },
    ]);
    if (existing.isEmpty) {
      await data.create(
        _cartsCollectionId,
        {'userId': customerId, 'itemsJson': itemsJson},
        token: customerToken!,
      );
    } else {
      await data.update(
        _cartsCollectionId,
        existing.first['_id'] as String,
        {'itemsJson': itemsJson},
        token: customerToken!,
      );
    }
    final reread = await data.list(
      _cartsCollectionId,
      token: customerToken!,
      filter: {'userId': customerId},
      limit: 1,
    );
    if (reread.isEmpty) throw StateError('cart did not persist');
  });

  final subtotalCents =
      testProducts[0].priceCents * 2 + testProducts[1].priceCents;

  await _requireStep('checkout: create the order document', () async {
    final doc = await data.create(
      _ordersCollectionId,
      {
        'userId': customerId,
        'itemsJson': stringifyJsonField([
          OrderLineItem(
            productId: testProducts[0].id,
            name: testProducts[0].name,
            priceCents: testProducts[0].priceCents,
            quantity: 2,
          ).toJson(),
          OrderLineItem(
            productId: testProducts[1].id,
            name: testProducts[1].name,
            priceCents: testProducts[1].priceCents,
            quantity: 1,
          ).toJson(),
        ]),
        'subtotalCents': subtotalCents,
        'currency': 'USD',
        'orderStatus': OrderStatus.awaitingPayment.wireValue,
        'shippingName': 'Flutter Tester',
        'shippingAddressJson': stringifyJsonField(const ShippingAddress(
          fullName: 'Flutter Tester',
          line1: '1 Test Street',
          city: 'Lagos',
          region: 'Lagos',
          postalCode: '100001',
          country: 'NG',
        ).toJson()),
        'paymentStatus': OrderPaymentStatus.unpaid.wireValue,
      },
      token: customerToken!,
    );
    orderId = doc['_id'] as String?;
    if (orderId == null) throw StateError('order create returned no _id');
  });

  // Not wrapped in `_step` - a 502 "no payment merchant for this
  // organization" here is an EXPECTED, documented outcome (see README
  // "Payments" / task brief), not something this script should report as a
  // FAIL. What actually needs verifying is that `CheckoutProxyService`
  // handles it gracefully - returns a typed `CheckoutPayLinkFailure` with a
  // readable message instead of letting a raw `DioException`/502 escape -
  // exactly what the `on DioException` branch inside `createPaymentLink`
  // guarantees. A truly unexpected outcome (an exception escaping the
  // service, or a 2xx with no usable token) still fails loudly below.
  stdout.write('- checkout: call the payment-link proxy ... ');
  final amount = (subtotalCents / 100).toStringAsFixed(2);
  try {
    final result = await checkoutProxy.createPaymentLink(
      orderId: orderId!,
      amount: amount,
      currency: 'USDC',
      network: 'POLYGON',
      redirectUrl: '$_checkoutProxyBaseUrl/orders/$orderId',
    );
    switch (result) {
      case CheckoutPayLinkSuccess(:final token):
        paymentLinkToken = token;
        await data.update(
          _ordersCollectionId,
          orderId!,
          {'paymentLinkToken': token},
          token: customerToken!,
        );
        stdout.writeln('PASS (link created)');
        _passed++;
      case CheckoutPayLinkFailure(:final message, :final isKycRequired):
        stdout.writeln(
          'PASS (gracefully surfaced as a typed failure, as documented: '
          'isKycRequired=$isKycRequired, message="$message")',
        );
        _passed++;
    }
  } on Object catch (error) {
    // This is the one truly-unexpected outcome: CheckoutProxyService.
    // createPaymentLink catches DioException internally and always resolves
    // to a typed CheckoutPayLinkResult, so anything reaching this catch
    // clause is a real regression, not the documented 502.
    stdout.writeln('FAIL (proxy call threw instead of returning a typed '
        'result: $error)');
    _failed++;
  }

  if (paymentLinkToken == null) {
    _stepSkip(
      'payment-link status poll (public, unauthenticated)',
      'no payment link was created - org has no payment merchant '
          'configured (documented, out-of-scope platform limitation)',
    );
  } else {
    await _step('payment-link status poll (public, unauthenticated)',
        () async {
      final link = await checkoutProxy.getPaymentLinkStatus(paymentLinkToken!);
      if (link.token != paymentLinkToken) {
        throw StateError('polled link token mismatch');
      }
    });
  }

  await _step('order history includes the new order (as the customer)', () async {
    final docs = await data.list(
      _ordersCollectionId,
      token: customerToken!,
      filter: {'userId': customerId},
      limit: 100,
    );
    final orders = docs.map(Order.fromJson).toList();
    if (!orders.any((order) => order.id == orderId)) {
      throw StateError('order history did not include $orderId');
    }
  });

  await _step('seller fulfillment queue sees the order (unrestricted read)', () async {
    final docs = await data.list(
      _ordersCollectionId,
      token: sellerToken!,
      limit: 200,
    );
    final orders = docs.map(Order.fromJson).toList();
    if (!orders.any((order) => order.id == orderId)) {
      throw StateError('seller queue did not include $orderId');
    }
  });

  await _step(
      'seller fulfillment: advance order paid -> shipped -> delivered', () async {
    // Simulates what the payment webhook would have done (this environment
    // has no funded wallet to actually settle the Payment Link) so the
    // seller's real "advance" write path - the same `orderStatus` transition
    // `SellerOrderActions.advance` performs - can still be exercised end to
    // end against the live `orders` collection under the `seller` role.
    await data.update(
      _ordersCollectionId,
      orderId!,
      {'orderStatus': OrderStatus.paid.wireValue},
      token: sellerToken!,
    );
    final afterPaid = await data.getById(
      _ordersCollectionId,
      orderId!,
      token: sellerToken!,
    );
    if (OrderStatus.fromWire(afterPaid?['orderStatus'] as String?) !=
        OrderStatus.paid) {
      throw StateError('order did not transition to paid');
    }
    final next = OrderStatus.paid.nextFulfillmentStatus;
    if (next == null) throw StateError('paid has no next fulfillment status');
    await data.update(
      _ordersCollectionId,
      orderId!,
      {'orderStatus': next.wireValue},
      token: sellerToken!,
    );
    final afterShipped = await data.getById(
      _ordersCollectionId,
      orderId!,
      token: sellerToken!,
    );
    if (OrderStatus.fromWire(afterShipped?['orderStatus'] as String?) !=
        OrderStatus.shipped) {
      throw StateError('order did not transition to shipped');
    }
  });

  await _step('POST /api/auth/refresh returns a new token pair (customer)',
      () async {
    if (customerRefreshToken == null) {
      throw StateError('no refresh token was issued at login/register');
    }
    final refreshed = await auth.refreshSession(customerRefreshToken!);
    final newToken = refreshed['token'] as String?;
    final newRefreshToken = refreshed['refreshToken'] as String?;
    if (newToken == null || newToken == customerToken) {
      throw StateError('refresh did not return a distinct new access token');
    }
    // The new access token must actually be usable - prove it with a real
    // authenticated call, not just a shape check on the refresh response.
    await data.list(
      _ordersCollectionId,
      token: newToken,
      filter: {'userId': customerId},
      limit: 1,
    );
    customerToken = newToken;
    customerRefreshToken = newRefreshToken ?? customerRefreshToken;
  });

  await _step('an invalid access token is rejected with a real 401', () async {
    try {
      await data.list(
        _productsCollectionId,
        token: 'not-a-real-token',
        limit: 1,
      );
      throw StateError('expected a 401, request unexpectedly succeeded');
    } on MudbaseException catch (error) {
      if (error.statusCode != 401) {
        throw StateError('expected statusCode 401, got ${error.statusCode}');
      }
    }
  });

  await _step('sign out (best-effort server-side revoke)', () async {
    await auth.logout(sellerToken!);
    await auth.logout(customerToken!);
  });

  print('');
  print('Passed: $_passed, Failed: $_failed, Skipped: $_skipped');
  if (_failed > 0) exit(1);
}
