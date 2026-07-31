# Commonwealth Goods (Ruby) — Mudbase Showcase Ecommerce

A production storefront built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and payments, with **zero custom backend** for data. This is the Ruby
reimplementation of the reference storefront (see the companion Next.js app at `../web`):
same Mudbase project, same collections, same field shapes, same payment-link delegation —
different stack. Server-rendered with **Sinatra + ERB**, talking to `cloud.mudbase.dev`
through the real generated **Mudbase Ruby SDK** (`mudbase_sdk`, module `MudbaseSDK`).

## Stack

Sinatra 4 + ERB + Rack::Session::Cookie, `mudbase_sdk` (git-sourced), Puma. No ORM, no
database of its own — every read/write goes to Mudbase's Collections REST API.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Customer accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `lib/mudbase/auth_service.rb`, `MudbaseSDK::MultiRoleFeatureApi#register_with_role` |
| Seller/admin accounts | A second Multi-Role, `seller` (provisioned out-of-band, no self-signup UI) | see "Provisioning" below |
| Product catalog | Collections, role-scoped read (`authenticated`) + role-scoped write (`seller`) | `app/routes/catalog_routes.rb`, `lib/mudbase/products_repo.rb` |
| Multi-photo gallery + discounts | JSON-string field (`galleryJson`), plain `compareAtPriceCents` number field | `lib/mudbase/json_field.rb`, `views/seller/product_form.erb` |
| Cart, per user | Collections, ownership-conditioned CRUD (`customer` + `{userId: "$userId"}`) | `lib/mudbase/carts_repo.rb` |
| Checkout + orders | Collections, ownership-conditioned create/read/update + unrestricted seller read/update | `app/routes/checkout_routes.rb`, `lib/mudbase/orders_repo.rb` |
| Payments | Payment Links (non-custodial stablecoin, USDC/POLYGON) - delegated | `lib/mudbase/payment_link_client.rb`, `views/checkout/pay.erb` |
| Seller fulfillment queue | Unrestricted `seller`-role read/update on `orders` | `app/routes/seller_routes.rb`, `views/seller/dashboard.erb` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled.
2. Multi-Role feature initialized with two roles: the default `customer` role, and a custom
   `seller` role (`signupEndpoint: "seller"`, no approval/payment/KYC gate).
3. Three collections — `products`, `orders`, `carts` — with the field/permission shapes
   documented in `../web/plan/build-plan.md` (same project as every other per-language
   reimplementation of this storefront).
4. At least one `seller`-role account to manage the catalog (there is no self-service
   "become a seller" flow in this UI, matching the reference web app).

## Setup

```bash
bundle install
cp .env.example .env   # fill in your own provisioned project's IDs and a session secret
bundle exec puma -p 4567 config.ru
# or: bundle exec rackup config.ru
```

Open `http://localhost:4567`.

### Native-extension (ffi) caveat

`mudbase_sdk` depends on `typhoeus` -> `ethon` -> `ffi` for its HTTP transport. `ffi`'s native
extension is loosely pinned by the SDK's own gemspec and can fail to compile against a newer
Xcode/Clang toolchain than the gem release expects. This Gemfile pins `ffi ~> 1.17` explicitly
(a version with prebuilt `arm64-darwin`/`x86_64-darwin`/Linux bottles, so `bundle install`
typically doesn't need to compile anything at all). If you still hit a build failure:

```
ffi-x.y.z... has:
  extconf.rb failed... -bundle_loader ... unrecognized command line option
```

first try `gem install ffi -v '~> 1.17'` on its own to confirm a prebuilt binary gem is
available for your platform before touching the vendored SDK gemspec (do not edit it directly
— the fix belongs in this app's own Gemfile, which is exactly what the `ffi` pin above does).

### Verifying the app

```bash
find . -name "*.rb" -exec ruby -c {} \;   # every file: Syntax OK
bundle exec ruby -e "require './app'"     # loads cleanly, no live network calls
```

There is no live Mudbase project wired up in this environment, so full request flows
(register/login/browse/checkout against a real project) weren't exercised end-to-end here.
What *was* verified: every route boots and every ERB view renders without a runtime error
(driven through a real in-process Rack::Test session, with only the network-touching
repository methods swapped for fixtures), and the auth error path was confirmed live against
the real `cloud.mudbase.dev` API (an invalid project ID correctly surfaces
`{"error": "Authentication error"}` as an on-page flash message rather than crashing).

## Known limitations (real platform + SDK constraints, not bugs)

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`lib/mudbase/json_field.rb`). This is a documented constraint of the Collections feature, not
a workaround specific to this app.

**A field literally named `status` is globally protected.** Mudbase's server-side
role-assignment guard blocks any collection write that includes a `status` key, for every
project end-user regardless of role or collection permissions. The `orders` collection's
status field is named `orderStatus` to work around this (see `lib/mudbase/orders_repo.rb`).

**File uploads require an org owner/admin/developer system role.** Every project end-user,
sellers included, is permanently a `viewer` system role and gets denied. Product images in this
demo are entered as plain URLs rather than uploaded (`views/seller/product_form.erb`).

**Payment Link creation is delegated to the reference web app, on purpose.** Creating a
Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live org owner/admin bearer
token — there is no API-key path for it, and the generated Ruby SDK has **no dedicated Payment
Links API class at all** (confirmed by grepping every `lib/mudbase_sdk/api/*.rb` file in the
gem — it isn't part of the OpenAPI surface this client was generated from). Rather than mint
and hold that merchant credential in yet another per-language reimplementation of this same
storefront (a real race condition the moment two of them rotate the same single-use merchant
refresh token concurrently), this app POSTs to the already-deployed Next.js reference app's
`/api/checkout/pay-link` Route Handler, which holds that credential once, server-side. See
`lib/mudbase/payment_link_client.rb`. If that proxy returns `403`/`kyc_required`, this app
surfaces an honest "payments pending identity verification" message rather than faking success.

**Generated-SDK gaps this app works around, not by editing the vendored gem** (updated after a
2026-07-31 SDK regen fixed two of the three original gaps):

1. ~~`MultiRoleFeatureApi#register_with_role` generated with return type `nil`~~ — **fixed by
   the regen.** `register_with_role_with_http_info` now defaults `return_type` to the real typed
   `RegisterWithRole201Response` (and its `RegisterWithRole201ResponseUser` submodel declares
   `custom_role`), so the signup response is no longer silently discarded even without any
   override. ~~`RegisterWithRoleRequest` doesn't declare `agreedToTerms`~~ — **fixed by the
   regen.** The model now declares `agreed_to_terms` (wire key `agreedToTerms`, setter rejects
   `nil`) as a normal constructor argument, so the old `debug_body:` JSON-splice hack for this
   field is gone. `AuthService.register_customer!` still passes `debug_return_type: "Object"`
   on this call, but only so its response can share one Hash-shaped parsing path with `login!`
   (see point 2, which still applies to login) rather than maintaining two different
   `AuthSession#user` construction paths for the same struct. See `lib/mudbase/auth_service.rb`.
2. **Still open.** Every "returns a document" model (`DataListResponseDataInner`,
   `LoginLocalUser200ResponseUser`, `CreateAnonymousSession200ResponseUser`) only types the
   handful of fields the generator could see in the spec (`_id`/`created_at`/`updated_at` for
   collection documents; no `customRole`/`isAnonymous` on these endpoint-specific user
   submodels, even though the real API returns them - confirmed against the reference Next.js
   app's own `UserObject` type). The regen *did* add `custom_role`/`is_anonymous` to the
   standalone `User` model, but not to these per-endpoint response submodels, so the gap
   persists for every login and every collection read. Typed deserialization would silently
   drop every product/order/cart field and the `customRole` this app's seller-area gating
   depends on. Every `DataApi`/`AuthenticationApi`/`MultiRoleFeatureApi` call in this app
   therefore still passes `debug_return_type: "Object"` (see
   `Mudbase::ClientFactory::OBJECT_RESPONSE`) to get the real parsed JSON as a plain Hash
   instead. Worth flagging back to Mudbase: the generated Ruby client's document/user models
   are effectively unusable as typed objects for this SDK's own dynamic-schema collections.

**Per-request SDK configuration, not the documented global `MudbaseSDK.configure` pattern.**
Every generated `*Api` class defaults to `MudbaseSDK::Configuration.default` /
`MudbaseSDK::ApiClient.default`, both process-wide singletons. Calling the documented
`MudbaseSDK.configure { |c| c.access_token = jwt }` per request would mutate that shared
singleton — a real race condition in a multi-threaded Puma server, where request A could pick
up request B's bearer token. This app instead builds a fresh `Configuration.new` +
`ApiClient.new(config)` per request and hands it explicitly into every generated API
constructor (`lib/mudbase/client_factory.rb`).

**No anonymous/guest browsing.** Unlike the reference Next.js app (which establishes an
anonymous Mudbase session on first load so guests can browse and cart before creating an
account), this Ruby reimplementation was scoped without that requirement. Since the `products`
collection's read permission is granted to the `authenticated` role only (not a public/
anonymous role), every page here — including the catalog — requires signing in first. A guest
flow could be added the same way `AuthService.login!` works today, using
`MudbaseSDK::AuthenticationApi#create_anonymous_session`.

**Refresh-token rotation.** The Mudbase-issued JWT and its single-use, rotate-on-use refresh
token are held server-side in an httponly, signed+encrypted Rack session cookie
(`Rack::Session::Cookie`) — never sent to client JavaScript. Every route that talks to Mudbase
routes its access token through `SessionHelpers#with_access_token`, which mirrors the reference
Next.js app's `MudbaseClient#request` retry wrapper: it proactively refreshes a token within 60
seconds of its tracked expiry, and — the same as that wrapper — reactively refreshes and retries
exactly once on a real `401` from the server (clock drift, a token revoked out from under a live
session, etc.), via `AuthService.refresh!` (`MudbaseSDK::AuthenticationApi#refresh_token`). Only
when the refresh token itself is rejected does the session actually get logged out - that
`MudbaseSDK::ApiError` propagates to `app.rb`'s global 401 handler, which clears the session and
redirects to `/login` with a "please sign in again" message, rather than a raw error page.

## Local development

```bash
bundle install
cp .env.example .env
bundle exec puma -p 4567 config.ru
```

## Deploy

Any Ruby host that runs Puma behind `config.ru` (Fly.io, Render, a bare VPS with systemd) works
unmodified. Set every variable in `.env.example` as a real environment variable —
`SESSION_SECRET` must be a long random value distinct from any other app's secret, and
`RACK_ENV=production` turns on the `secure` cookie flag (HTTPS-only session cookie).
