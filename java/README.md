# Commonwealth Goods — Java (Spring Boot) edition

A production storefront built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database,
and payments — reimplemented in **Spring Boot + Thymeleaf** (server-rendered, no client-side JS
framework). This is a companion to the reference Next.js app at `../web`: same Mudbase project,
same collections, same business rules, same checkout flow — different stack.

## Stack

Java 17, Spring Boot 3.3 (Web MVC, not WebFlux), Thymeleaf, Bean Validation. The only outbound
HTTP this app makes are: (1) the real Mudbase Java SDK against `cloud.mudbase.dev`, and (2) two
plain calls to the already-deployed reference web app's payment-link proxy — see "Why a proxy"
below. No database of its own; Mudbase collections are the only persistence.

## Setup

### 1. Install the Mudbase SDK to your local Maven repository (one-time, mandatory)

The SDK is **not published to Maven Central** — it lives at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), subdirectory `java/`.
Clone it as a **sibling** of this repo (same parent directory as `mudbase-showcase-ecommerce/`),
then install it into `~/.m2`:

```bash
# from the same parent directory that contains mudbase-showcase-ecommerce/
git clone https://github.com/mudbase/mudbase-sdk.git

cd mudbase-showcase-ecommerce/java
cd ../../mudbase-sdk/java && mvn install
```

This installs `dev.mudbase:mudbase-sdk:2.0.0` into your local repo. `pom.xml` in this project then
depends on it via a normal `<dependency>` block — no repository/URL wiring needed beyond that.

### 2. Configure environment variables

```bash
cp .env.example .env
# fill in your provisioned Mudbase project's IDs
set -a && source .env && set +a
```

See `.env.example` for the full list and what each value is for. You need a Mudbase project
already provisioned with local auth, the Multi-Role feature (`customer` + `seller` roles), and the
three collections (`products`, `orders`, `carts`) shaped as documented in `../web/plan/build-plan.md`
— this app assumes that provisioning already exists, exactly like the reference web app does.

### 3. Build and run

```bash
cd mudbase-showcase-ecommerce/java
mvn compile        # verify it builds clean
mvn spring-boot:run
```

Visit `http://localhost:8080`.

## What's implemented

| Page | Route | Notes |
|---|---|---|
| Product catalog | `GET /` | Category filter via query param; public, no sign-in required |
| Product detail | `GET /products/{slug}` | Photo gallery with click-to-swap thumbnails, add-to-cart |
| Cart | `GET /cart`, `POST /cart/{add,update,remove}` | Guest cart lives in the HttpSession until sign-in |
| Checkout | `GET/POST /checkout` | Inline sign-in/register for guests, then shipping form |
| Payment status | `GET /checkout/{token}`, `GET /checkout/{token}/status` | Polls Mudbase's public payment-link endpoint via a same-origin JSON proxy |
| Order history | `GET /orders`, `GET /orders/{id}` | Requires a real account (customer or seller) |
| Login / Register | `GET/POST /login`, `GET/POST /register` | Registration is always the `customer` role — no role picker |
| Seller dashboard | `GET /seller` | Order fulfillment queue + product table, gated on `customRole == "seller"` |
| Seller product CRUD | `GET/POST /seller/products/**` | Create/edit/delete, gated the same way |

Session/auth: the Mudbase-issued JWT is stored server-side in the Spring `HttpSession` — it is
never sent to the browser (pages are plain server-rendered HTML; the only client JS is the
payment-status poller and a couple of inline `Add to cart` quantity buttons, neither of which ever
sees the token).

## Architecture notes

- **`mudbase/`** wraps the generated SDK: `MudbaseDataClient` (thin `DataApi` wrapper with
  document-shape normalization), `MudbaseAuthClient` (register/login/logout/anonymous-session),
  `DocumentMapper`/`JsonFields` (the `Map<String,Object>` <-> domain conversions and the
  JSON-string-field parsing every Mudbase Collections app needs — see "Known limitations").
- **`domain/`** holds plain, immutable value types (`Product`, `Order`, `Cart`, `CartItem`, records
  where appropriate) with `fromDocument(Map)` factories and display-formatting helpers, so
  Thymeleaf templates never touch raw Mudbase JSON.
- **`service/`** is where every Mudbase call happens, always passing the caller's own bearer token
  — Mudbase's collection permissions (ownership conditions on `orders`/`carts`, role-gated CRUD on
  `products`) are the real security boundary, not anything in this app.
- **`auth/`** bridges the `HttpSession` to Mudbase: `SessionAuthService` holds the current
  `AuthSession`, `GuestCartHolder` holds the pre-login cart, and two `HandlerInterceptor`s gate
  `/orders/**` (sign-in required) and `/seller/**` (seller role required) — UX gates only, same as
  the reference app's `SellerGuard` component; the actual authorization happens server-side on
  Mudbase.
- **Public catalog browsing without sign-in** uses a lazily-created anonymous Mudbase session
  (`AuthenticationApi.createAnonymousSession`), cached in the `HttpSession` for its lifetime — this
  satisfies the `products` collection's "authenticated role, read-only" permission before a real
  account exists, the same mechanism the reference Next.js app uses on first visit.

## Known limitations (real platform constraints, not bugs)

These mirror `../web/README.md`'s own "Known limitations", plus a few specific to reimplementing
this in a real generated Java SDK rather than a hand-rolled TypeScript client.

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`mudbase/JsonFields.java`). Documented platform constraint, not a workaround specific to this app.

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard blocks any collection write containing a `status` key for every project end-user regardless
of role. The `orders` collection's status field is named `orderStatus` throughout this app to work
around it — see `domain/OrderStatus.java`.

**File uploads require an org owner/admin/developer system role**, which every project end-user
(sellers included) is denied. Product images are entered as plain URLs in the seller product form,
same as the reference app.

**The generated `RegisterWithRoleRequest` SDK model doesn't match what the live endpoint actually
requires.** `POST /api/auth/local/signup/{role}` requires `agreedToTerms` in the body (the
reference web app's own client sends it and notes "a direct API call without it is rejected"), but
the OpenAPI-generated `RegisterWithRoleRequest` model only has
`email`/`password`/`firstName`/`lastName`/`projectId` — no field for it — and the generated
`MultiRoleFeatureApi.registerWithRole` method's return type is `void` (the response body isn't
modeled for this endpoint either). Rather than force a mismatched typed call, `MudbaseAuthClient`
invokes this one endpoint directly over the SDK's own shared `OkHttpClient` and base path, with a
hand-written response DTO mirroring the sibling `RegisterLocalUser201Response` model (the same
underlying local-auth registration handler, just role-scoped). Every other auth and data call in
this app uses the real generated `AuthenticationApi`/`DataApi` — this is the one deliberate,
documented exception. Worth flagging back to Mudbase: the multi-role signup endpoint's OpenAPI spec
looks incomplete relative to its actual runtime validator.

**The generated user shape is inconsistent across sibling auth endpoints.** `loginLocalUser`'s
response types the project app-role field `role` (`LoginLocalUser200ResponseUser.role`), while
`registerLocalUser`'s response types the same concept `customRole`
(`RegisterLocalUser201ResponseUser.customRole`) and `getLocalSession`'s response types its `user`
field as a raw untyped `Object`. This app treats all three as the same semantic value (the
project's app-role, e.g. `"customer"` or `"seller"`) — see the comment in
`mudbase/MudbaseAuthClient.java#login`.

**Guest cart lives in the servlet `HttpSession`, not `localStorage`.** The reference Next.js app
keeps a pre-login cart in the browser's `localStorage` because it's a client-rendered SPA; this
server-rendered app has no client-side storage layer to reuse, so the equivalent guest cart lives
in the `HttpSession` (`auth/GuestCartHolder.java`) for the duration of the browser session, then
migrates into the real `carts` collection the moment the shopper registers or signs in — same
merge-don't-clobber logic as the reference app's `migrateGuestCartToServer`.

**Gallery photos are one URL per line in a textarea, not a dynamic field array.** The reference
React app's seller product form has an "Add photo" button backed by `useFieldArray`; a
server-rendered form with no client JS field-array wiring uses a plain multi-line textarea instead,
split on newlines into the same `galleryJson` string field. Functionally equivalent, less polished
UI.

**No refresh-token rotation.** Like the reference web app (which never calls `POST /api/auth/refresh`
either), this app uses the JWT issued at login/register for the life of the session and does not
implement Mudbase's refresh-token rotation. A session that outlives its JWT's expiry gets a 401 from
Mudbase, which this app treats as "session expired" and redirects to `/login` — there is no
automatic silent refresh.

**No Spring Security / CSRF tokens.** Every state-changing endpoint is a plain `POST` handled by a
`@Controller` method with Bean Validation; there is no CSRF token, session-fixation protection, or
security-header configuration beyond what Spring Boot's Tomcat defaults provide. Reasonable for a
reference/demo storefront exercising Mudbase's own API surface; not what you'd ship to production
traffic. Mudbase's own collection permissions remain the actual authorization boundary regardless.

**Why a payment-link proxy exists (`CHECKOUT_PROXY_BASE_URL`, `/api/checkout/pay-link`).** Creating
a Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live org owner/admin bearer
token — there is no API-key path for it, and a project end-user's token can never carry an org
role. Rather than every per-language reimplementation of this storefront (Java, Go, Python, PHP,
Ruby, Swift, React Native, ...) independently minting and rotating that single-use merchant refresh
token — a real race condition the moment two of them run concurrently — this app delegates that one
call to the already-deployed reference Next.js app's Route Handler, which holds that credential.
Everything else (auth, product reads, cart, order create/read, seller queue, and the public
payment-link *status* read) talks to `cloud.mudbase.dev` directly.

**Payment Links require the org to be KYC-approved.** If the org isn't approved yet, the proxy
returns `403` with `reason: "kyc_required"`; this app surfaces that as an honest "payments pending
identity verification" notice on the order detail page rather than faking a successful charge.

## Local development

```bash
mvn spring-boot:run
```

Thymeleaf template caching is disabled by default in this repo's `application.properties`
(`THYMELEAF_CACHE=false`) so edits to `.html` files under `src/main/resources/templates` show up
on refresh without a restart.

## Verification performed

`mvn compile` builds clean. The full request pipeline (real SDK calls to `cloud.mudbase.dev`,
error handling, session/cart state, Thymeleaf rendering) was smoke-tested end-to-end against the
**real** Mudbase API using a placeholder project ID — every call correctly reaches
`cloud.mudbase.dev` and real API responses (429 rate limits, 404s, validation errors) are parsed
and rendered rather than crashing. Full business-flow testing (a real catalog, a real checkout,
a real payment) requires a live provisioned project and was out of scope per this task's own
instructions.
