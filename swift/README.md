# Mudbase Showcase — Ecommerce (SwiftUI / iOS)

A production-shaped SwiftUI iOS storefront built on top of [Mudbase](https://www.mudbase.dev),
reimplementing the same reference storefront ("Commonwealth Goods") as the companion Next.js app
in `../web/` — same collections, same permissions model, same checkout/payment flow. Auth,
catalog, cart, orders, and the seller dashboard all talk directly to `cloud.mudbase.dev` through
the real generated Mudbase Swift SDK; creating a Payment Link is delegated to the already-deployed
web app's server-side proxy (see "Payments" below).

## Why SPM, not an `.xcodeproj`

This package is deliberately `.xcodeproj`-free. Since Xcode 14, you can open a `Package.swift`
directly and run an `executableTarget` that defines a SwiftUI `App` (`@main`) as a real iOS app on
a Simulator or device — Xcode synthesizes the Info.plist/bundle at build time, no project file
needed. That keeps this reimplementation's on-disk footprint identical in spirit to the other
per-language versions in this monorepo (`../web/`, `../mobile-expo/`, etc.): source + a manifest,
nothing generated or binary checked in. `swift build` from the CLI also succeeds on plain macOS —
the `platforms` list in `Package.swift` includes `.macOS(.v14)` purely so this can be verified
without Xcode; no UIKit-only API is used anywhere in the target (guarded behind small compatibility
shims where SwiftUI itself differs — see `Support/PlatformCompat.swift`).

## Setup

1. **Clone the SDK as a sibling directory.** From the same parent directory that contains this
   monorepo (`mudbase-showcase-ecommerce/`):
   ```bash
   git clone https://github.com/mudbase/mudbase-sdk.git
   ```
   You should end up with:
   ```
   parent/
     mudbase-showcase-ecommerce/
       swift/            <- this package (Package.swift lives here)
       web/
       ...
     mudbase-sdk/
       swift/            <- the SDK package Package.swift references
       ...
   ```

2. **Create the SwiftPM identity-collision workaround symlink.** This app's own SPM package
   directory is named `swift` (see the monorepo layout above) and the SDK's own Swift subdirectory
   is *also* named `swift`. SwiftPM computes a local path dependency's package "identity" from the
   last path component of the path you give it, with no way to override that — so a plain
   `.package(path: "../../mudbase-sdk/swift")` gives this app's own package and its SDK dependency
   the *same* identity ("swift"), and dependency resolution silently conflates them. The symptom is
   a resolution failure that looks like the product doesn't exist even though it plainly does:
   ```
   error: product 'MudbaseSDK' required by package 'swift' target 'MudbaseShowcaseEcommerce' not found in package 'MudbaseSDK'
   ```
   The fix is a relative symlink, committed at the *monorepo root* (sibling to this `swift/`
   directory, `web/`, etc.), that gives the dependency a distinct final path segment:
   ```bash
   # from mudbase-showcase-ecommerce/ (the monorepo root)
   ln -s ../mudbase-sdk/swift mudbase-sdk-swift
   ```
   `Package.swift` references `../mudbase-sdk-swift` (not `../../mudbase-sdk/swift`) for exactly
   this reason — see the comment on the `.package(...)` line. This symlink is small and portable
   (a relative path, so it survives being cloned anywhere as long as the sibling-clone layout
   holds) and is committed to the repo so nobody else has to rediscover this.

3. **Configure.** Copy `Config.example.plist` to `Config.plist` (same directory) and fill in your
   Mudbase project's IDs:
   ```bash
   cp Config.example.plist Config.plist
   ```
   | Key | Value |
   |---|---|
   | `MudbaseProjectId` | Your Mudbase project ID |
   | `MudbaseBaseURL` | `https://cloud.mudbase.dev` (default, rarely needs changing) |
   | `ProductsCollectionId` | The `products` collection's ID |
   | `OrdersCollectionId` | The `orders` collection's ID |
   | `CartsCollectionId` | The `carts` collection's ID |
   | `PayLinkProxyBaseURL` | `https://mudbase-showcase-ecommerce.vercel.app` (default) |

   None of these are secrets (a project/collection ID isn't sensitive — same rationale as
   `web/.env.example`). `Config.plist` is still gitignored to keep per-developer project IDs out of
   history; there is no `MUDBASE_MERCHANT_*` credential in this app at all — see "Payments" below
   for why. `AppConfig.load` also reads `MUDBASE_PROJECT_ID` / `MUDBASE_PRODUCTS_COLLECTION_ID` /
   etc. environment variables as a fallback, which is convenient for `swift run` during
   development; if neither source resolves every required key, the app renders a
   "Configuration required" screen instead of crashing (see `ConfigurationRequiredView.swift`).

4. **Open and run.**
   ```bash
   open Package.swift
   ```
   In Xcode: pick an iOS Simulator (or a physical device) as the run destination from the scheme
   selector, then Run. If you add `Config.plist` to the project navigator, make sure it's added to
   the `MudbaseShowcaseEcommerce` target's "Copy Bundle Resources" build phase (Xcode does this
   automatically when you drag the file in with "Add to target" checked).

## What's implemented

- **Auth** — email/password login and self-signup (always `customer`, no role picker — see
  "Provisioning" below), session bootstrap from Keychain on launch, logout. Token pair stored in
  the Keychain via `Support/KeychainTokenStore.swift` — never `UserDefaults`. A 401 from an
  expired access token is transparently refreshed and retried once, for *every* authenticated
  call in the app (not just launch bootstrap) — see `Networking/AccessTokenCoordinator.swift`.
- **Catalog** — product grid with category filter (re-fetches per category, matching the web app),
  product detail with an image carousel (main image + `galleryJson` gallery) and an add-to-cart
  stepper.
- **Cart** — server-backed (`carts` collection), one document per signed-in customer, read-then-
  create-or-update since Mudbase has no native upsert.
- **Checkout** — shipping address form → creates the order doc → calls the web app's
  `/api/checkout/pay-link` proxy → payment status screen that polls the public payment-link
  endpoint until it reaches a terminal state.
- **Orders** — order history and order detail (timeline, line items, shipping address, a
  "Complete payment" link back into the payment status screen for an unpaid order).
- **Seller area** — gated on the signed-in user's `customRole == "seller"`: product list
  (create/edit/delete) and an order fulfillment queue with one-tap `paid → shipped → delivered`
  transitions.

## Architecture

```
Sources/MudbaseShowcaseEcommerce/
  App/            @main entry point
  Config/         AppConfig (Config.plist + env var loader)
  Support/        Keychain, JSON-field codec, formatting, API error mapping, platform shims
  Networking/     Thin wrappers over the generated SDK's async calls + the pay-link proxy client
  Models/         Product, Order, CartItem, AppUser, PaymentLink — decoded from Mudbase JSON
  Services/       SessionStore, CartStore (both @MainActor ObservableObject), ProductsService, OrdersService
  ViewModels/     One @MainActor ObservableObject per screen
  Views/          SwiftUI views, grouped by feature area
```

`SessionStore` and `CartStore` are the two app-wide stores (created once in the `App` struct and
injected via `.environmentObject`); every other view model is constructed explicitly by its owning
view (passed `config` and, where relevant, the shared `CartStore`) rather than reached for via
`@EnvironmentObject`, so each screen's real dependencies stay visible at its call site.

## The Mudbase Swift SDK, exactly as generated

Every Mudbase call in this app goes through the real generated `MudbaseSDK` async/await methods —
none of the signatures below were guessed; each was read from `../../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift`
before being used:

- `AuthenticationAPI.loginLocalUser`, `.getLocalSession`, `.refreshToken`, `.logoutLocalUser`
- `MultiRoleFeatureAPI.registerWithRole(role:registerWithRoleRequest:)`
- `DataAPI.listData` / `.getData` / `.createData` / `.updateData` / `.deleteData`

The SDK was regenerated since this app was first built, closing two of the three gaps originally
documented here. What's left, and what changed, is documented in code comments at the call sites
(`Networking/AuthGateway.swift`):

- **`registerWithRole` now returns a typed `RegisterWithRole201Response`** (previously `Void` — the
  OpenAPI spec behind `POST /api/auth/local/signup/{role}` didn't give the generator a single
  typed success body, since the shape varies with `requireEmailVerification`). When verification
  isn't required, that response carries the token pair *and* the user (`RegisterWithRole201ResponseUser`,
  which — unlike `LoginLocalUser200ResponseUser` — already includes `customRole`) directly, so
  `SessionStore.register` no longer needs a follow-up `login` + `getLocalSession` round trip to
  obtain a real session; it trusts the register response itself. The `EMAIL_VERIFICATION_REQUIRED`
  path (register screen shows "check your email, then sign in") is unchanged, driven now by the
  response's own `requireVerification` flag.
- **`RegisterWithRoleRequest` now has an `agreedToTerms` field**, matching Mudbase's registration
  validator (which requires it for a direct signup call). The Terms & Privacy checkbox's
  client-side-enforced value (`RegisterViewModel.agreedToTerms`) is now actually transmitted through
  `AuthGateway.registerCustomer` — previously it was validated client-side only, with no way to send
  it through the typed SDK call at all.
- **`LoginLocalUser200ResponseUser` still has no `customRole`** — that gap remains. Only
  `GetLocalSession200Response.user` (typed as a raw `JSONValue`, not a fixed struct — the generator
  can't know ahead of time what custom roles a project's Multi-Role feature defines) carries it, so
  every *login* (not register, now — see above) is still followed by a `getLocalSession` call for
  exactly this reason — `AuthGateway.currentUser()`.

## Payments

Creating a Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live **org owner/admin**
bearer token — there is no API-key path for it, and a project end-user's token can never carry an
org role. Embedding an org credential in a mobile app binary would be a real security hole (anyone
can extract strings from an IPA), so this app never attempts to create a Payment Link itself.
Instead, `Networking/PayLinkGateway.swift` calls the already-deployed web app's
`POST https://mudbase-showcase-ecommerce.vercel.app/api/checkout/pay-link` Route Handler, which
holds that merchant session server-side. A `403` with `reason: "kyc_required"` is surfaced
honestly as "payments pending identity verification," not swallowed or faked as a success.

The payment status screen polls the *public*, unauthenticated
`GET https://cloud.mudbase.dev/api/payment-links/:token` endpoint every 4 seconds until the link
reaches a terminal status (`paid`/`expired`/`cancelled`), continuing through transient fetch errors
— the same behavior as the web app's `usePaymentLinkStatus` hook.

## Provisioning

This app expects the same already-provisioned Mudbase project the web app does (see
`../web/README.md` "Provisioning" and `../web/plan/build-plan.md`): local auth, Multi-Role with
`customer` + `seller`, and the `products`/`orders`/`carts` collections with the field/permission
shapes documented there. There's no self-service "become a seller" flow in this UI, by design —
seller accounts are provisioned out-of-band.

## Known limitations (real platform/SDK constraints, not bugs)

Carried over from `../web/README.md`, since they're constraints of the Mudbase platform itself, not
anything specific to the web implementation:

- **Mudbase Collections have no native array/object field type.** Order line items, shipping
  addresses, and extra product images are JSON-encoded strings, parsed at the edges
  (`Support/JSONField.swift`).
- **A field literally named `status` is globally protected** by Mudbase's server-side
  role-assignment guard, for every project end-user regardless of role. The `orders` collection's
  status field is named `orderStatus` to work around this (`Models/Order.swift`).
- **File uploads require an org owner/admin/developer system role.** Every project end-user,
  sellers included, is permanently a `viewer` system role. Product images are entered as plain URLs
  in the seller product form rather than uploaded, for the same reason the web app does this.
- **No native upsert.** `CartStore`'s cart writes are read-then-create-or-update, re-fetching the
  authoritative document immediately before deciding which — see the doc comment on
  `CartStore.persist`.
- **This app requires login before browsing at all** (no anonymous/guest session, per this
  project's own build brief) — unlike the web app, which uses an anonymous Mudbase session so
  guests can browse the catalog before creating an account. This is a deliberate simplification:
  the products collection's read permission only requires `authenticated` (any logged-in role), and
  a native app's install-then-launch flow makes "sign in first" a reasonable default that the web
  app's link-shareable pages don't have.
- **The SwiftPM package-identity collision** described in "Setup" step 2 above — a genuine SwiftPM
  constraint (identity = last path component, no override), not a bug in this app's manifest, but
  worth knowing about if you ever change how the SDK dependency is referenced.
- **The one remaining generated SDK gap** described in "The Mudbase Swift SDK, exactly as
  generated" above — no `customRole` on the *login* response — still shapes `SessionStore.login`
  (a `getLocalSession` follow-up call). The `registerWithRole` returning `Void` and the missing
  `agreedToTerms` field were both closed by a later SDK regeneration; `SessionStore.register` no
  longer needs its own follow-up call as a result.
- **Certificate pinning and biometric auth are out of scope for this reference build.** The
  project's own security rules call for both on a production mobile app; they're omitted here to
  keep this a focused reimplementation of the same reference storefront the web version covers, not
  a full production hardening pass. Token storage (Keychain, never `UserDefaults`) is implemented,
  since that's a baseline correctness issue rather than an additive hardening feature.
