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

**`AuthenticationApi.loginLocalUser` fails with a 500 for every real Multi-Role account.** This
is more than the naming inconsistency above — it's a live crash, found and fixed during this app's
own end-to-end testing. The generated `LoginLocalUser200ResponseUser` model is deserialized with
Gson, which hard-fails (`IllegalArgumentException`, same failure class as the `listData`/`Pagination`
mismatch below) the instant the response JSON has a property the model doesn't declare. Every
account created via this project's Multi-Role feature — i.e. every seller/customer this app ever
creates — gets a login response whose `user` object carries **both** `role` and `customRole`; the
generated model only declares `role`. `MudbaseAuthClient#login` now bypasses the generated method
the same way registration does: a raw call over the SDK's shared `OkHttpClient`, parsed leniently
with a Jackson `@JsonIgnoreProperties(ignoreUnknown = true)` DTO instead of the strict generated
Gson model. Worth flagging back to Mudbase alongside the registration and listData mismatches:
the login endpoint's OpenAPI spec is missing a field its own live handler always returns.

**`DataApi.listData` also fails against the live API — every list call in this app bypasses it.**
Its generated `Pagination` model hard-fails (`IllegalArgumentException`, not even the SDK's own
checked `ApiException`) the instant a response includes a `hasMore` field the model never declared
— confirmed against every single `listData` call this app makes (catalog, seller product/order
queues, cart, order history). `MudbaseDataClient#listRaw` bypasses `DataApi.listData` entirely with
the same raw-call-plus-lenient-Jackson-parsing pattern as the two auth mismatches above — see that
method's javadoc.

**A single page render that needs more than one Mudbase call can spuriously "expire" a session
that was just successfully refreshed.** Found and fixed during this app's own end-to-end testing,
the same underlying bug class every other per-language reimplementation of this storefront (Go,
Python, Ruby, C#, PHP, Swift, Flutter) also hit: several controllers (e.g. `SellerController#dashboard`,
which lists both orders and products for the seller) read the signed-in `AuthSession` once and pass
that same snapshot's access token into two or more sequential `MudbaseDataClient` calls. If the
token had expired, the *first* call would 401, silently refresh via the stored refresh token, and
retry successfully — but the *second* call still carried the pre-refresh token, so it 401'd too,
and `SessionAuthService#recoverFromUnauthorized` treated a token mismatch as "a different request
already refreshed this session, nothing to do," discarding the perfectly valid session it had just
created and forcing a spurious "session expired, please sign in again" logout. The fix: a token
mismatch now means "the session already holds something newer than what just failed," so the
current session token is handed back for an immediate retry instead of being treated as a lost
cause — verified end-to-end against the live API by deliberately corrupting a session's access
token while keeping its real refresh token and confirming `/seller` (which makes exactly this kind
of multi-call request) now renders successfully instead of logging the seller out.

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

**Transparent refresh-token rotation.** Unlike the reference web app (which never calls `POST
/api/auth/refresh`), this app stores the refresh token issued alongside every login, register, and
anonymous-session call in the `HttpSession` (`AuthSession.refreshToken`). `MudbaseDataClient#execute`
retries every collection call exactly once on a 401: it hands the failed token to
`SessionAuthService#recoverFromUnauthorized`, which exchanges the stored refresh token for a new
access/refresh pair via `POST /api/auth/refresh` (not under the login/register rate limit) and
persists the rotated pair back into the session before the original call is silently re-issued with
the new token. Only when there is no session, no refresh token on file, or the refresh call itself
fails does the original 401 propagate to `GlobalExceptionHandler`, which then clears the session and
redirects to `/login` as the terminal "session expired" behavior.

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

`mvn clean install` builds clean. The full business flow was run end-to-end against the **real**,
live, provisioned Mudbase project (`cloud.mudbase.dev`), not a placeholder: seller sign-in, seller
product creation, public catalog browsing, customer sign-in, add-to-cart, checkout (shipping form
→ order creation → payment-link request), order history, and back to the seller fulfillment queue
to advance an order's status. Every one of those calls hit the real API - no mocks, no stubs.

That pass surfaced and fixed three real, previously-undiscovered bugs (see "Known limitations"
above for full detail on each):

1. **`SessionAuthService#recoverFromUnauthorized` discarded a just-refreshed valid session** when
   a single page made more than one Mudbase call from the same pre-refresh token snapshot (e.g.
   the seller dashboard listing both orders and products) - fixed by treating a token mismatch as
   "retry with what's already there" instead of "give up."
2. **`AuthenticationApi.loginLocalUser` crashed with a 500 for every real Multi-Role account**
   because the generated response model doesn't declare the `customRole` field every such
   account's login response actually carries - fixed the same way registration's own generated-model
   mismatch was already fixed: a raw call parsed leniently with Jackson instead of the strict
   generated Gson model.
3. **Carts and orders always rendered empty**, despite persisting correctly to Mudbase, because
   `JsonFields`'s round trip serialized `CartItem`/`OrderLineItem`'s derived getters
   (`getLineTotalCents()` and friends) into the stored JSON, then failed to read that same JSON
   back under Jackson's default strict unknown-property handling - fixed by disabling
   `FAIL_ON_UNKNOWN_PROPERTIES` on the shared mapper.

The one call this app does not fully control - creating a Payment Link via the deployed reference
app's proxy - failed during this test run (the demo org has no approved payment merchant / the
proxy's own merchant refresh token was invalid), exactly the documented, out-of-scope platform
limitation described above. The app surfaced that honestly on the order detail page rather than
faking a successful charge or crashing - confirmed working as designed, not a bug.
