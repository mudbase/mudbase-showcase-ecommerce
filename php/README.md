# Mudbase Showcase — Ecommerce (PHP)

A plain-PHP reimplementation of the Commonwealth Goods storefront — the same business logic,
schema, and UX flows as the [Next.js reference app](../web) (`../web/README.md`,
`../web/plan/build-plan.md`), rebuilt with **no framework**: `php -S`-runnable, server-rendered
pages, one small router/dispatch file, and the real generated **Mudbase PHP SDK**
(`mudbase/sdk`, namespace `Mudbase\Sdk`) for every Mudbase call.

## Stack

Plain PHP 8.1+, no framework — matches the platform's own "the API is the backend" philosophy.
Composer only for autoloading (PSR-4) and the SDK dependency. Native PHP sessions hold the
Mudbase-issued JWT server-side; it is never sent to client JS. A handful of `<script>` tags exist
only for the payment-status poll and the seller order-queue short-poll (see "Known limitations").

## Setup

1. **Clone the SDK as a sibling directory.** This app's `composer.json` declares a `path`
   repository pointing at `../../mudbase-sdk/php` — i.e. `mudbase-sdk` must be cloned **next to**
   `mudbase-showcase-ecommerce`, in the same parent directory:

   ```
   your-workspace/
   ├── mudbase-showcase-ecommerce/
   │   └── php/                 ← this app
   └── mudbase-sdk/
       └── php/                 ← composer package `mudbase/sdk`
   ```

   ```bash
   cd your-workspace
   git clone https://github.com/mudbase/mudbase-sdk.git
   ```

   > The SDK's `php/composer.json` must declare `"name": "mudbase/sdk"` for Composer's `path`
   > repository to resolve `"require": {"mudbase/sdk": "*"}` against it — if your clone predates
   > that field being added upstream, add it yourself (one line) before running `composer install`.

2. **Install dependencies:**

   ```bash
   cd mudbase-showcase-ecommerce/php
   composer install
   ```

3. **Provision Mudbase** (see `../web/README.md` "Provisioning" for the full checklist — same
   project, same collections, this app just reads/writes them differently):
   - Local auth enabled.
   - Multi-Role feature initialized with `customer` (default) and a custom `seller` role
     (`signupEndpoint: "seller"`, no approval/payment/KYC gate).
   - Three collections — `products`, `orders`, `carts` — with the field/permission shapes in
     `../web/plan/build-plan.md`.
   - At least one `seller`-role account (no self-service "become a seller" flow — see Known
     Limitations).

4. **Configure environment:**

   ```bash
   cp .env.example .env
   # fill in MUDBASE_PROJECT_ID and the three collection IDs
   ```

5. **Run:**

   ```bash
   php -S localhost:8080 -t public public/router.php
   ```

   Visit `http://localhost:8080`.

## What's implemented

| Feature | Where |
|---|---|
| Guest browsing (anonymous Mudbase session, auto-established on first request) | `src/bootstrap.php` |
| Product catalog + category filter | `src/Controllers/HomeController.php`, `src/views/home.php` |
| Product detail (multi-photo gallery via link-based thumbnail nav, no JS) | `src/Controllers/ProductController.php`, `src/views/product_detail.php` |
| Cart (guest cart in the PHP session; real cart in the `carts` collection once signed in as `customer`) | `src/Support/Cart.php` |
| Register / login (role always `customer` for self-signup) / logout | `src/Controllers/AuthController.php` |
| Checkout → order creation → delegated Payment Link creation → payment status page | `src/Controllers/CheckoutController.php`, `src/Support/PaymentLinkProxy.php` |
| Order history + order detail (ownership-scoped) | `src/Controllers/OrderController.php` |
| Seller dashboard: order fulfillment queue (short-polled) + product CRUD | `src/Controllers/SellerController.php` |
| CSRF protection on every state-changing form | `src/Http/Csrf.php` |

### Structure

```
public/
├── index.php          front controller: builds the Router, defines every route, dispatches
├── router.php          php -S entry point (serves static assets, else requires index.php)
└── assets/             style.css, seller-poll.js (see "Known limitations")
src/
├── bootstrap.php        session start, env load, anonymous-session handshake, AppContext wiring
├── Config.php            .env loader
├── Router.php            tiny {param}-pattern router
├── View.php               view-in-layout renderer
├── Mudbase/
│   ├── MudbaseClient.php    thin wrapper over the real generated SDK (see docblock for two
│   │                        documented SDK gaps this class works around)
│   └── MudbaseApiError.php  decodes the SDK's ApiException into a usable message/status/details
├── Support/
│   ├── Json.php, Money.php        JSON-string-field + formatting helpers
│   ├── Cart.php                    guest-session-cart ⇄ server-cart logic
│   └── PaymentLinkProxy.php        calls the delegated pay-link endpoint + the public status read
├── Http/
│   ├── AppContext.php, Flash.php, Csrf.php, Response.php
├── Controllers/         one file per route group
└── views/                plain .php view files, one per page, plus layout.php + partials/
```

## Known limitations (real platform + reimplementation constraints, not bugs)

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`src/Support/Json.php`) — a documented constraint of the Collections feature itself, not specific
to this app. Same as the reference Next.js app.

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard blocks any collection write containing a `status` key, for every project end-user regardless
of role or collection permissions. The `orders` collection's status field is named `orderStatus`
to work around this — matches the reference app exactly.

**File uploads require an org owner/admin/developer system role.** Every project end-user,
including a `seller` customRole account, is permanently a `viewer` system role and is denied
`rbacCheck("file", "create")`. Product images here are entered as plain URLs (main image URL field
+ a "one per line" textarea for extra photos) rather than uploaded, same constraint as the
reference app — a real fix needs either a relaxed file-permission model for end-users or a
server-side upload proxy using an org-level credential (the same pattern as the payment-link
proxy below).

**The generated PHP SDK's `DataApi::listData()` silently drops every custom collection field.**
Its typed response model, `DataListResponseDataInner`, only declares `_id`, `created_at`,
`updated_at` (see `mudbase-sdk/php/docs/Model/DataListResponseDataInner.md`) — a real gap in the
OpenAPI spec's response schema for dynamic, user-defined collections (the single-document
endpoints don't have this problem: their `data` property is typed as a passthrough `object`).
`MudbaseClient::listDocuments()` calls the SDK's own `DataApi::listDataRequest()` — a public method
that builds the same signed request — and decodes the JSON body itself instead of routing it
through the lossy typed deserializer. See the docblock on `src/Mudbase/MudbaseClient.php` for the
full explanation, including the matching gap in `registerWithRole()` (generated as `void`, so
registration is two chained SDK calls: register, then log in).

**Login/register/anonymous-session response models omit `customRole` and `isAnonymous`.** Only
`GetLocalSession200Response.user` is typed as a passthrough `object` in the spec; the narrower
typed user objects returned directly by login/register/anonymous-session do not declare those
fields. This app always calls `getLocalSession()` right after any auth mutation to get the full,
authoritative user object — every role gate in this app (`isCustomer()`, `isSeller()`) depends on
that field surviving deserialization.

**No realtime seller dashboard.** The reference app subscribes to a Socket.IO room for live order
updates; a server-rendered PHP page has no persistent connection to subscribe with. The seller
order queue instead short-polls `GET /seller/orders-fragment` every 5 seconds
(`public/assets/seller-poll.js`) and swaps in the refreshed HTML fragment — new/updated orders show
up within a few seconds instead of instantly.

**No hover image-cycling / carousel autoplay on product cards.** Those are JS-only micro-
interactions in the reference SPA. The product detail page still supports manual gallery
navigation (thumbnail links swap the main image via a `?photo=N` query param, no JS required); the
catalog grid shows only the primary image.

**One Mudbase round trip to establish a session per fresh visit, not per page load.** A stateless
SPA re-validates its session once per client mount; this server-rendered app re-mounts on every
request, so re-validating with `getLocalSession()` on every single page view would mean one extra
Mudbase call per page. Instead, the user snapshot from the last successful auth call is cached in
the PHP session and trusted across requests. If a token actually expires mid-session, the next API
call that hits it returns 401, which the front controller catches, clears the session, and
redirects back to the same URL to re-bootstrap as a fresh guest (see `public/index.php`).

**Payment Link creation is delegated, not implemented here.** Creating a Payment Link requires a
live org owner/admin bearer session with no API-key path. Rather than this (and every other
per-language reimplementation of this storefront) independently holding and rotating the same
single-use merchant refresh token — a real race condition the moment two run concurrently — this
app POSTs to the already-deployed reference Next.js app's Route Handler
(`PAY_LINK_PROXY_URL` in `.env`, default `https://mudbase-showcase-ecommerce.vercel.app/api/checkout/pay-link`),
which owns that merchant session server-side. A `403`/`kyc_required` response is surfaced verbatim
as "this store's payments are still pending identity verification," not faked into a success path.
The public payment-link status read (`GET /api/payment-links/:token`) needs no auth and goes
straight to Mudbase, both server-side (initial page render) and client-side (the poll script on
`checkout_payment.php`).

**CSRF tokens, not full framework-grade session hardening.** Every state-changing form carries a
per-session CSRF token (`src/Http/Csrf.php`), and the session ID is regenerated on every
authentication/privilege change. There is no rate limiting at this layer — Mudbase's own
per-endpoint rate limits are the enforcement boundary, same as the reference app's own security
notes.

## Local development

```bash
composer install
cp .env.example .env   # fill in your own provisioned project's IDs
php -S localhost:8080 -t public public/router.php
```

Without a live Mudbase project configured, the app still boots and every page renders — collection
reads/writes surface a "couldn't load"/error flash instead of a fatal error (see
`src/bootstrap.php` and every controller's `try`/`catch MudbaseApiError`).
