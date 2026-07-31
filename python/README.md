# Mudbase Showcase — Ecommerce (Python)

A server-rendered **FastAPI + Jinja2** reimplementation of the reference storefront at
[`../web`](../web), backed entirely by the real **Mudbase Python SDK**
(`mudbase-sdk`, generated via OpenAPI Generator, published at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk)) — same Mudbase
project, same collections, same business rules, different stack and delivery model
(request/response HTML instead of a client-side SPA talking directly to `cloud.mudbase.dev`).

## Stack

FastAPI (async) + Jinja2 templates + vanilla CSS/JS (no bundler). Session state (the
Mudbase JWT, refresh token, and user profile) lives only in a signed, httpOnly Starlette
session cookie — it is never sent to browser JS, unlike the reference SPA which necessarily
holds its token in `localStorage` for direct browser-to-Mudbase calls.

## What's implemented

| Feature | Where |
|---|---|
| Guest catalog browsing (anonymous Mudbase session) | `app/session.py::ensure_anonymous_session` |
| Customer registration / login / logout | `app/routers/auth.py`, `app/services/auth_service.py` |
| Product catalog + category filter | `app/routers/catalog.py`, `app/templates/index.html` |
| Product detail + photo gallery (vanilla-JS carousel) | `app/routers/catalog.py`, `app/static/js/carousel.js` |
| Cart (server-persisted, `customer`-role only) | `app/routers/cart.py`, `app/services/carts.py` |
| Checkout → order creation → Payment Link | `app/routers/checkout.py`, `app/services/orders.py`, `app/services/payments.py` |
| Payment status page (polls until paid/expired) | `app/templates/checkout_payment.html`, `app/static/js/payment_poll.js` |
| Order history + detail + timeline | `app/routers/orders.py` |
| Seller dashboard: order fulfillment queue + product CRUD | `app/routers/seller.py` |

Every `products`/`orders`/`carts` collection read/write goes through the real
`mudbase_sdk.DataApi` and `mudbase_sdk.AuthenticationApi` against `cloud.mudbase.dev` (see
`app/mudbase_client.py`). Creating a Payment Link is deliberately **not** implemented here —
see "Known limitations" below.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in your provisioned project's IDs (see web/README.md "Provisioning")
python -c "import secrets; print(secrets.token_urlsafe(48))"   # → SESSION_SECRET_KEY
uvicorn app.main:app --reload
```

Visit `http://localhost:8000`. Seller accounts are not self-service (see below) — sign up as
a customer via `/register`, or log in with a pre-provisioned seller account via `/login`.

### Type checking

```bash
pip install mypy
mypy app   # strict mode, config in mypy.ini — should report zero issues
```

## Architecture notes

- **`app/mudbase_client.py`** wraps the real (synchronous, urllib3-based) `mudbase_sdk` with
  `asyncio.to_thread` adapters so FastAPI's async handlers never block the event loop.
- Two auth endpoints bypass the generated *typed* wrapper methods in favor of the SDK's own
  public `ApiClient.param_serialize` + `ApiClient.call_api` building blocks (documented in
  detail in that file's module docstring):
  - **Registration** (`POST /api/auth/local/signup/{role}`) — the generated
    `RegisterWithRoleRequest` model only declares `email/password/firstName/lastName/projectId`,
    but the live endpoint's validator additionally requires `agreedToTerms` (the same gap the
    reference web app's hand-rolled TS client documents in `web/src/lib/mudbase.ts`). Its
    generated response type is also declared `void`, which would silently discard the
    token/user payload the endpoint actually returns.
  - **Login** (`POST /api/auth/local/login`) — the generated response's nested user model has
    no `customRole` field (the Multi-Role feature was evidently added to the platform after
    this SDK version was generated), and `customRole` is exactly what this app needs to gate
    the seller area. Both calls parse the raw JSON response themselves instead of trusting the
    incomplete typed model, while still using `mudbase_sdk.ApiClient`'s configuration, host,
    and auth-header machinery.
- Payment Link **creation** and **status polling** are not covered by this SDK version at all
  (no `PaymentLinksApi`), so both go through `httpx` directly — matching how the reference
  Next.js app itself calls them (plain `fetch`, not its own SDK client).

## Known limitations (real platform/architecture constraints, not bugs)

**No guest-cart-to-account bridging.** The reference SPA lets an anonymous visitor add items
to a `localStorage` cart and migrates it into a real server-side cart at checkout, once they
register. Carts in Mudbase are `customer`-role-only with no ownership escape hatch, and this
app has no persistent client-side identity to bridge from a signed-out request to a signed-in
one (no long-lived browser state at all — every request is stateless HTML). Instead: catalog
browsing works for anyone (backed by a per-visit anonymous Mudbase session, see
`ensure_anonymous_session`), but "Add to cart" and checkout both require being signed in as a
`customer` first. A real production version of this pattern would need a durable
device/browser identifier issued on first visit and carried through registration — deliberately
not built here to keep this reimplementation focused on faithfully mirroring the reference
app's *server-side* business logic rather than re-solving its client-state problem.

**JSON-string array/object fields.** Mudbase Collections have no native array/object field
type — order line items, shipping addresses, and extra product images are stored as
JSON-encoded strings and parsed at the edges (`app/json_field.py`). Same documented platform
constraint as `web/src/lib/json-field.ts`, not a workaround specific to this app.

**No native upsert for carts.** Every cart mutation re-reads the authoritative document first,
then creates or updates (`app/services/carts.py`), mirroring the same duplicate-cart race
condition the reference app's `useCart.ts` documents and guards against.

**A field literally named `status` is globally blocked.** Mudbase's server-side
role-assignment guard rejects any collection write containing a `status` key, for every
project end-user regardless of role — the `orders` collection's status field is named
`orderStatus` to work around this. Real platform constraint, not a typo.

**File uploads require an org owner/admin/developer system role.** No project end-user,
including a `seller` customRole account, can upload to a Mudbase bucket. Product images are
entered as plain URLs (`seller_product_form.html`), same as the reference app.

**Payment Link creation is delegated, not implemented.** Creating a Payment Link requires a
live org owner/admin bearer session with no API-key path. Rather than every per-language
reimplementation of this showcase independently holding and rotating the same single-use
merchant refresh token (a real race condition across concurrently-running apps), this app
POSTs to the already-deployed reference web app's `/api/checkout/pay-link` Route Handler,
which holds that credential. A `403`/`kyc_required` response is surfaced as an honest
"payments pending identity verification" message, matching the reference app's behavior.

**No realtime seller dashboard.** The reference SPA subscribes to a Socket.IO room so new
orders appear in the seller queue without a refresh. This app is plain request/response HTML;
the seller dashboard reflects the database state as of the last page load. Out of scope for a
faithful-but-simpler server-rendered reimplementation, not a missing feature by oversight.

**No self-service "become a seller" flow.** Matches the reference app exactly — a `seller`
account is assumed pre-provisioned on the Mudbase project (see `web/README.md`
"Provisioning"); self-registration via `/register` always creates a `customer` account.

**`requireEmailVerification` must be off for this project** for the login/registration flow to
behave as implemented (immediate session on signup). If it's on, `/register` surfaces the
"check your email, then sign in" message and does not start a session — correct, honest
behavior, not a crash, but checkout and cart then require a separate `/login` after verifying.
