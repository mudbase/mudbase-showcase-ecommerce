# Mudbase Showcase — Ecommerce (Go)

A server-rendered Go reimplementation of the [Next.js reference storefront](../web) — same
Mudbase project, same collections, same business rules — built against the real
[Mudbase Go SDK](https://github.com/mudbase/mudbase-sdk) (`github.com/mudbase/mudbase-sdk/go`).

Stack: Go's standard `net/http` + [chi](https://github.com/go-chi/chi) for routing,
`html/template` for server-rendered pages, [gorilla/sessions](https://github.com/gorilla/sessions)
for the signed, encrypted, httpOnly session cookie that holds the Mudbase JWT (there is no client
JS bundle, so the cookie is the only place a token can live). No database, no ORM, no custom
backend beyond this one Go binary talking directly to `cloud.mudbase.dev`.

## What it implements

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing, no signup | Anonymous auth (`POST /api/auth/anonymous`) | `internal/mbase/auth.go`, `internal/server/middleware.go` |
| Customer accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `internal/mbase/auth.go`, `internal/server/handlers_auth.go` |
| Seller accounts | The `seller` Multi-Role (provisioned out of band, no self-signup UI - same as the reference) | n/a |
| Product catalog | Collections, role-scoped read (`authenticated`) + role-scoped write (`seller`) | `internal/store/catalog.go` |
| Multi-photo gallery + discounts | `galleryJson` string field, `compareAtPriceCents` number field | `internal/models/product.go` |
| Cart, per user | Collections, ownership-conditioned CRUD (`customer` + `{userId: "$userId"}`); guest carts live in the session cookie until sign-in | `internal/store/cart.go`, `internal/session/session.go` |
| Checkout + orders | Collections, ownership-conditioned create/read/update + unrestricted seller read/update | `internal/store/orders.go`, `internal/server/handlers_checkout.go` |
| Payments | Payment Links (non-custodial stablecoin, USDC/POLYGON), via the shared proxy (see below) | `internal/store/paylink.go` |
| Seller fulfillment queue | Polling (see "Known limitations" - no Go realtime client) instead of Socket.IO | `internal/server/handlers_seller.go` |

## Setup

This app expects a Mudbase project already provisioned exactly as described in
[`../web/plan/build-plan.md`](../web/plan/build-plan.md) and [`../web/README.md`](../web/README.md)
("Provisioning"): local auth enabled, the Multi-Role feature with `customer` + `seller` roles, and
the `products` / `orders` / `carts` collections with their documented field/permission shapes.

```bash
cd go
cp .env.example .env      # fill in your project's IDs; see .env.example for what each var does
go build ./...
go vet ./...
go test ./...
go run ./cmd/server
```

Then open `http://localhost:8080`. Environment variables are loaded from the process environment
(via `os.Getenv`) - use `direnv`, `dotenv`-style tooling of your choice, or export them in your
shell before running.

## Known limitations (real platform + SDK constraints, not bugs)

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`internal/models/jsonfield.go`). Same documented constraint as the reference web app.

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard blocks any collection write containing a `status` key, for every project end-user regardless
of role or collection permissions. The `orders` collection's status field is named `orderStatus`
to work around this (`internal/models/order.go`).

**No native upsert on Collections.** `internal/store/cart.go`'s `SaveServerCart` reads a
customer's existing cart doc first, then creates or updates accordingly - same
read-then-create-or-update pattern as the reference app's `useCart.ts`.

**File uploads require an org owner/admin/developer system role** - every project end-user,
sellers included, is permanently a `viewer` system role and gets denied. Product images are
entered as plain URLs rather than uploaded, same as the reference app.

**Two real gaps in this vendored Go SDK build's generated types, both worked around explicitly in
`internal/mbase/auth.go`:**
- `RegisterWithRoleRequest` (the typed request for `POST /api/auth/local/signup/{role}`) has no
  `agreedToTerms` field and no additionalProperties passthrough, but the live endpoint's
  registration validator rejects a request that omits it. `Client.Register` builds and sends that
  request as a small direct HTTP call instead of through the generated `RegisterWithRole` method,
  using the same URL/method/headers the generated code would have used.
- Every auth response model (`User`, `LoginLocalUser200ResponseUser`,
  `CreateAnonymousSession200ResponseUser`, ...) omits `customRole` and `isAnonymous` entirely, even
  though the live API returns both (this app's seller-dashboard gating and guest/customer cart
  routing both depend on them). Every other auth call still executes through the real generated SDK
  method for request construction and error handling, then re-decodes the raw response body the
  client preserves after its own typed decode to recover those two fields - not a second request,
  just a second read of bytes already in memory.

**Why a shared payment-link proxy exists at all.** Creating a Payment Link
(`POST /api/orgs/:orgId/payment-links`) requires a live Mudbase org owner/admin bearer token - no
API-key path exists, and a project end-user's token can never carry an org role. Rather than this
Go app (or any of its sibling per-language reimplementations) independently holding and rotating
that single-use merchant refresh token - a real race condition the moment more than one
reimplementation runs at the same time - every one of them, this one included, calls the
already-deployed reference web app's `/api/checkout/pay-link` Route Handler
(`internal/store/paylink.go`), which owns that merchant session exclusively. `PAY_LINK_PROXY_URL`
in `.env.example` points at it by default.

**Payment Links require the org to be KYC-approved.** If the org isn't KYC-approved yet, the proxy
returns a 403 with `reason: "kyc_required"`; this app surfaces that as an honest "this store's
payments are still pending identity verification" message on the checkout page
(`internal/server/handlers_checkout.go`) rather than faking a success path.

**No Socket.IO realtime client for Go.** The reference web app's seller dashboard subscribes to
the `orders` collection's Socket.IO room for instant push updates. There's no official Mudbase Go
realtime client, and implementing the Socket.IO wire protocol from scratch was out of scope for
this reimplementation. The seller order queue instead polls a small HTML-fragment endpoint
(`GET /seller/orders/fragment`) every 5 seconds via a short inline script
(`internal/server/handlers_seller.go`, `templates/seller_dashboard.html`) - functionally
equivalent for a fulfillment queue, just not push-based.

**Guest cart storage differs from the web app by necessity, not by choice.** The reference SPA
keeps a guest cart in `localStorage`; a server-rendered Go app has no client-side JS state to keep
it in, so the guest cart instead lives in the same signed, encrypted session cookie as the Mudbase
JWT (`internal/session/session.go`). It migrates into a real server-side `carts` document the
moment the shopper registers or signs in during checkout, same as the reference app's
`migrateGuestCartToServer`.

**No dynamic "add another photo" button on the seller product form.** Without a JS framework
driving form state, the product form renders a fixed 8 gallery-URL input slots up front (matching
the reference app's `MAX_GALLERY_PHOTOS`) instead of a JS-driven add/remove list. Blank slots are
simply ignored on submit - a deliberate simplification, not a missing feature.

**No password-reset UI**, matching the reference app's own v1 scope (the Mudbase endpoints exist
and are documented, just not wired into either app's UI yet).
