# Mudbase Showcase — Flutter

A Flutter reimplementation of the [Mudbase Showcase ecommerce storefront](../web) — catalog, cart,
checkout with Mudbase Payment Links, order history, and a seller fulfillment dashboard — talking
directly to `cloud.mudbase.dev` through the real, generated **Mudbase Dart SDK**
(`mudbase_sdk`, [github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk),
`dart/` subdirectory).

## Stack

Flutter + Dart, Riverpod (`flutter_riverpod`, no code generation) for state, go_router for
navigation, `flutter_secure_storage` for the auth token. See "Architecture decisions" below for why
plain Riverpod rather than the `riverpod_generator`/`freezed` combo this project's `flutter/SKILL.md`
otherwise defaults to.

## Setup

The Mudbase Dart SDK is **not published to pub.dev** — `pubspec.yaml` references it as a relative
path dependency assuming a sibling-clone layout:

```yaml
mudbase_sdk:
  path: ../../mudbase-sdk/dart
```

`mobile-flutter/` sits one level inside the `mudbase-showcase-ecommerce` repo, so reaching a flat
sibling of that repo takes exactly two `../` segments (`mobile-flutter/` → `mudbase-showcase-ecommerce/`
→ parent → `mudbase-sdk/dart`).

Before anything else, clone `mudbase-sdk` as a sibling of `mudbase-showcase-ecommerce` itself (same
parent directory):

```bash
# from the directory that contains mudbase-showcase-ecommerce/
git clone https://github.com/mudbase/mudbase-sdk.git
```

So the layout looks like:

```
some-parent-dir/
├── mudbase-sdk/
│   └── dart/                  ← the SDK pubspec.yaml lives here
└── mudbase-showcase-ecommerce/
    └── mobile-flutter/        ← this app
```

Then:

```bash
cd mobile-flutter

# First time only (or after upgrading Flutter) - generates/refreshes the
# android/, ios/, etc. platform folders. Safe to re-run; it only fills in
# missing platform scaffolding, it does not touch lib/ or pubspec.yaml.
flutter create .

flutter pub get

cp dart_define.example.json dart_define.json
# fill in dart_define.json with your provisioned project's IDs (see below)

flutter run --dart-define-from-file=dart_define.json
```

### Config (`--dart-define-from-file`, this project's Flutter convention)

Never a runtime `.env` file — every value is read via `String.fromEnvironment` in
`lib/config/env_config.dart`. `dart_define.example.json` documents every key:

| Key | Required | Notes |
|---|---|---|
| `MUDBASE_PROJECT_ID` | yes | Not a secret - same as the web app's `NEXT_PUBLIC_MUDBASE_PROJECT_ID`. |
| `PRODUCTS_COLLECTION_ID` | yes | |
| `ORDERS_COLLECTION_ID` | yes | |
| `CARTS_COLLECTION_ID` | yes | |
| `MUDBASE_BASE_URL` | no (defaults to `https://cloud.mudbase.dev`) | |
| `CHECKOUT_PROXY_BASE_URL` | no (defaults to the deployed web app) | See "Payments" below. |

`main()` calls `EnvConfig.assertConfigured()` before `runApp` and fails fast with a clear message
if any required key is missing, rather than surfacing a confusing 404/401 on the first screen that
reads an empty collection ID.

There is **no merchant/org secret anywhere in this app** — Payment Link creation is fully delegated
to the already-deployed web app's Route Handler (see "Payments" below), so nothing privileged ever
ships inside the mobile bundle.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Customer accounts (self-signup, always `customer`) | Multi-Role signup, `POST /api/auth/local/signup/customer` | `lib/features/auth/`, `lib/core/auth_service.dart` |
| Seller accounts | The `seller` Multi-Role, provisioned once outside this app (no self-service "become a seller" flow) | `lib/features/seller/` |
| Product catalog | Collections, role-scoped read (`authenticated`) + role-scoped write (`seller`) | `lib/features/catalog/`, `products` collection |
| Multi-photo gallery + discounts | `galleryJson` (JSON-string array) + `compareAtPriceCents` | `lib/features/catalog/widgets/image_gallery.dart` |
| Cart, per user | Collections, ownership-conditioned CRUD (`customer` + `{userId: "$userId"}`) | `lib/features/cart/`, `lib/data/repositories/cart_repository.dart` |
| Checkout + orders | Collections, ownership-conditioned create/read/update + unrestricted seller read/update | `lib/features/checkout/`, `orders` collection |
| Payments | Payment Links (non-custodial stablecoin, USDC/POLYGON) via the web app's proxy | `lib/core/checkout_proxy_service.dart`, `lib/features/checkout/payment_status_screen.dart` |
| Seller fulfillment queue | `seller` role's unrestricted `orders` read/update | `lib/features/seller/seller_dashboard_screen.dart` |

## Auth flow (a deliberate simplification vs. the web app)

The web app supports anonymous guest browsing that converts to a real account at checkout. This
mobile app requires sign-in (login or register) before browsing at all — the brief explicitly
allowed either approach, and the anonymous-guest flow's main value (browse-before-committing) is
weaker on mobile, where installing the app is already a bigger commitment than opening a web page.
This also sidesteps guest-cart-in-local-storage-then-merge-on-registration entirely, which is real
complexity the web app carries (see `web/src/hooks/useCart.ts`'s `migrateGuestCartToServer`) that
this app doesn't need.

Self-signup is always the `customer` role (`RegisterScreen`, role hidden). There is no self-service
"become a seller" flow — a `seller` account is seeded once during Mudbase project provisioning, same
as the web app.

## Payments

Creating a Mudbase Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live org
owner/admin bearer token — there is no API-key path for it, and a project end-user's token (what
this app ever holds) can never carry an org role. So checkout never calls that endpoint directly;
it POSTs to the **already-deployed web app's** `/api/checkout/pay-link` Route Handler
(`lib/core/checkout_proxy_service.dart`), which holds that merchant credential server-side and
creates the link on the customer's behalf, after the `orders` document is created client-side under
the signed-in customer's own account. The payment-status screen then polls
`GET /api/payment-links/:token` (public, no auth) directly against `cloud.mudbase.dev` every 4
seconds until the link reaches a terminal status.

If the org isn't KYC-approved yet, the proxy returns `403 { reason: "kyc_required" }` and checkout
surfaces "this store's payments are still pending identity verification" honestly, rather than
faking a success.

## Architecture decisions

- **Riverpod without code generation.** `flutter/SKILL.md`'s default stack uses
  `riverpod_generator` + `freezed` + `build_runner`. This app uses plain `Notifier`/`AsyncNotifier`
  classes and hand-written model classes instead, specifically because this environment could not
  install the Flutter SDK to iteratively verify `build_runner` output locally — every provider and
  model here is verifiable by `dart analyze` alone, with no generated-code step that could silently
  drift from its source annotations between local writing and the first real `flutter pub get`.
- **No Socket.IO / realtime seller dashboard.** The web app subscribes to a `db:create`/`db:update`
  WebSocket room for live order updates. This app uses pull-to-refresh and manual refresh instead —
  simpler, and the brief didn't call for realtime specifically for the mobile version.
- **Category/search filtering is client-side.** The catalog screen fetches every active product
  once per visit and filters by category/search locally, rather than re-querying Mudbase on every
  keystroke or chip tap — appropriate at this showcase's catalog scale, and it means switching
  filters never shows a loading flicker.

## Known limitations (real platform/SDK constraints, not bugs)

**This app calls `sdk.dio` directly instead of the generated `AuthenticationApi`/
`MultiRoleFeatureApi`/`DataApi` wrapper classes**, for reasons confirmed by reading the generated
source in `mudbase-sdk/dart/lib/src/`, not guessed:

- `MultiRoleFeatureApi.registerWithRole` (`POST /api/auth/local/signup/{role}`) is typed to return
  `void` in the bundled OpenAPI spec, even though the live endpoint returns a JSON body with
  `token`/`refreshToken`/`user`.
- Every response model the SDK *does* type for auth (`LoginLocalUser200Response`, `User`,
  `CreateAnonymousSession200ResponseUser`, ...) declares `role` but not `customRole`/`isAnonymous`.
  built_value's standard JSON deserializer silently drops unknown fields instead of erroring, so
  going through the typed wrapper would silently lose exactly the field this app gates the seller
  area on.
- `DataApi.listData`'s typed response element, `DataListResponseDataInner`, only declares
  `_id`/`createdAt`/`updatedAt` (see its generated `_deserializeProperties` - every other key is
  routed into an `unhandled` list and discarded). Every product/order/cart field this app actually
  renders would be silently dropped from a list read.
- The Multi-Role signup endpoint's real-world validator additionally requires `agreedToTerms` in the
  request body (confirmed by the web app's own hand-rolled client, `web/src/lib/mudbase.ts`), a
  field the generated `RegisterWithRoleRequest` builder class has no slot for.

Request bodies still go through the SDK's real generated builder classes
(`RegisterWithRoleRequest`, `LoginLocalUserRequest`) and its own `Serializers` to produce the wire
payload wherever a builder exists for that request - only the response side (and the one
`agreedToTerms` field) is handled by hand. See `lib/core/auth_service.dart` and
`lib/core/mudbase_data_service.dart` for the exact reasoning inline.

**`galleryJson`/`itemsJson`/`shippingAddressJson` are JSON-encoded strings, not native arrays.**
Mudbase Collections have no native array/object field type - a real, documented platform
constraint, not a workaround specific to this app (see `lib/core/json_field.dart` and the web app's
own README).

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard blocks any collection write containing a `status` key for every project end-user regardless
of role - the `orders` collection's status field is named `orderStatus` to work around this (see
`lib/models/order.dart`).

**Product images are entered as plain URLs, not uploaded.** Mudbase file uploads require an org
owner/admin/developer *system* role; every project end-user (sellers included) is permanently a
`viewer` system role and is denied. `SellerProductFormScreen` accepts a hosted image URL instead of
an in-app picker/uploader.

**No native cart upsert.** `CartRepository.save` reads the existing `carts` document for the user
first and creates only if none exists, same read-then-create-or-update pattern as the web app's
`useCart`.

**Payment Links require the org to be KYC-approved**, re-checked live on every creation call - see
"Payments" above.

## Testing

`test/` covers the pure-logic layer with `flutter_test` (JSON field parsing, money/date formatting,
and the `Product`/`Cart`/`Order` model parsing, including the `orderStatus` wire-value mapping) —
run with:

```bash
flutter test
```

Screens are not covered by widget tests in this pass; the models, formatters, and JSON-field parsing
they all depend on are, which is where the actual Mudbase-specific edge cases (JSON-string fields,
enum wire values, missing/malformed data from the server) live.

## Verification

```bash
dart format --set-exit-if-changed .
dart analyze
flutter test
```
