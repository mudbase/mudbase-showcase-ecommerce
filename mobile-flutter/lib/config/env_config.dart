/// Compile-time configuration, supplied via `--dart-define` /
/// `--dart-define-from-file` — this project's Flutter convention (see
/// `flutter/SKILL.md`), never a runtime `.env` file. All values below are
/// either public (a Mudbase project/collection ID is not a secret, same as
/// the web app's `NEXT_PUBLIC_*` vars) or point at a public, unauthenticated
/// endpoint (the checkout proxy). There is no merchant/org secret in this
/// app at all - payment-link creation is fully delegated to the already
/// deployed web app's Route Handler, which is the only place that secret
/// lives. See README "Setup" for the full `--dart-define` list.
class EnvConfig {
  const EnvConfig._();

  static const String mudbaseBaseUrl = String.fromEnvironment(
    'MUDBASE_BASE_URL',
    defaultValue: 'https://cloud.mudbase.dev',
  );

  static const String mudbaseProjectId = String.fromEnvironment(
    'MUDBASE_PROJECT_ID',
  );

  static const String productsCollectionId = String.fromEnvironment(
    'PRODUCTS_COLLECTION_ID',
  );

  static const String ordersCollectionId = String.fromEnvironment(
    'ORDERS_COLLECTION_ID',
  );

  static const String cartsCollectionId = String.fromEnvironment(
    'CARTS_COLLECTION_ID',
  );

  /// The already-deployed web app's own origin. Checkout POSTs to
  /// `$checkoutProxyBaseUrl/api/checkout/pay-link` (see
  /// `lib/core/mudbase/checkout_proxy_service.dart`) instead of creating a
  /// Payment Link directly, because that call requires an org owner/admin
  /// bearer token that must never ship inside a mobile app bundle.
  static const String checkoutProxyBaseUrl = String.fromEnvironment(
    'CHECKOUT_PROXY_BASE_URL',
    defaultValue: 'https://mudbase-showcase-ecommerce.vercel.app',
  );

  /// Fails fast at startup (in `main()`) rather than surfacing a confusing
  /// mid-flow 404/401 the first time a screen tries to read an empty
  /// collection ID - mirrors the web app's `requireEnv()` in `lib/config.ts`.
  static void assertConfigured() {
    final missing = <String>[
      if (mudbaseProjectId.isEmpty) 'MUDBASE_PROJECT_ID',
      if (productsCollectionId.isEmpty) 'PRODUCTS_COLLECTION_ID',
      if (ordersCollectionId.isEmpty) 'ORDERS_COLLECTION_ID',
      if (cartsCollectionId.isEmpty) 'CARTS_COLLECTION_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required --dart-define values: ${missing.join(', ')}. '
        'See README "Setup" for the full list and how to supply them.',
      );
    }
  }
}
