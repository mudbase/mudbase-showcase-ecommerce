# Build Plan — Mudbase Showcase: Ecommerce
Generated: 2026-07-30
Mode: greenfield
Type: web (fullstack via BaaS, no custom backend)
Stack: Next.js 15 App Router + TypeScript + Tailwind CSS + shadcn/ui, backed entirely by Mudbase (cloud.mudbase.dev)

## Stack Decisions
- Next.js 15 App Router: project default for "Web App" per CLAUDE.md Stack Defaults; Server Components keep the Mudbase project ID server-visible without a client bundle leak, Client Components handle the interactive storefront (cart, auth forms).
- No Prisma/Postgres/Redis: the explicit constraint is zero custom backend — every persistence, auth, and realtime concern is a Mudbase REST/WebSocket call from the Next.js app (client-side via the browser, or server-side via Route Handlers where a privileged org-level credential is required).
- shadcn/ui + Tailwind: matches CLAUDE.md's Web App default and this session's design skills.
- TanStack Query: server-state cache for every Mudbase collection read/mutation, per `01-backend-core.md`/`web-app/SKILL.md` conventions.

## Feature Scope
1. Auth — anonymous guest session on first visit (browse + cart without an account), email/password registration and login via Mudbase local auth, in-place anonymous→real account conversion at checkout, logout.
2. Product catalog — Mudbase `products` collection, public (any signed-in-or-anonymous) read, seller-only write.
3. Cart — Mudbase `carts` collection, one document per user, server-persisted (survives device/browser change), ownership-scoped.
4. Checkout — creates an `orders` document, then a real Mudbase Payment Link (non-custodial stablecoin) for payment; checkout page polls the public payment-link read until paid or expired.
5. Order history — customer's own past orders (`orders` collection, ownership-filtered).
6. Seller/admin view — gated by `customRole === "seller"`: product CRUD (with image upload to Mudbase file storage) and an order fulfillment queue (all orders, status updates).
7. Realtime — the seller dashboard subscribes to the `orders` collection's WebSocket room and gets new/updated orders pushed live, no polling.
8. File storage — product images uploaded to a Mudbase bucket, served back via bucket file URLs.

## Data Models / Entities (Mudbase Collections — provisioned on the real platform, not simulated)
### products
Fields: name (string), slug (string, unique), description (string), priceCents (number), currency (string, default USD), imageUrl (url), galleryJson (string — JSON array of extra image URLs; Mudbase collection fields have no native array/object type, so multi-image galleries are stored JSON-encoded in a string field and parsed client-side), category (string), stock (number), isActive (boolean), sellerId (string)
Permissions: `seller` role → create/read/update/delete, unconditional. `authenticated` role → read, unconditional (covers both `customer` and `seller` customRoles and the anonymous-guest `viewer` system role once an anonymous session exists).

### orders
Fields: userId (string), itemsJson (string — JSON array of `{productId,name,priceCents,quantity}`), subtotalCents (number), currency (string), status (enum: pending|awaiting_payment|paid|shipped|delivered|cancelled), shippingName (string), shippingAddressJson (string), paymentLinkToken (string), paymentStatus (enum: unpaid|paid|expired|cancelled)
Permissions: `customer` role → create/read/update, condition `{ userId: "$userId" }` (server auto-populates and enforces ownership). `seller` role → read/update, unconditional (fulfillment queue).
Realtime: `enableRealtime: true` — seller dashboard subscribes to `collection:<ordersId>` `create`/`update` events.

### carts
Fields: userId (string, unique), itemsJson (string, default `[]`)
Permissions: `customer` role → create/read/update/delete, condition `{ userId: "$userId" }`. One document per user; upserted client-side (read-then-create-or-update, since Mudbase collections have no native upsert endpoint).

## Multi-Role Configuration
Two application roles via Mudbase's Multi-Role feature: `customer` (default starter role, no approval) and `seller` (custom role added at provisioning time, no approval/payment/KYC gate — single-storefront demo, not a marketplace). Both sign up via `/api/auth/local/signup/:role` with `role` = `customer` or `seller`.

## Auth Flow
```
First visit (no token) → POST /api/auth/anonymous → anonymous User created (customRole: null, systemRole: viewer)
                                                    → browse catalog, add to cart (both allowed via `authenticated`/ownership rules)
Checkout (still anonymous) → register form → POST /api/auth/anonymous/convert
                                            → same User._id, isAnonymous flips false, email/password set
                                            → cart + any placed orders remain attached (same userId)
Direct signup  → POST /api/auth/local/signup/customer  (buyer)
              → POST /api/auth/local/signup/seller     (store owner, used once to seed the demo)
Login          → POST /api/auth/local/login
Logout         → POST /api/auth/logout (revokes token + kills session)
```
There is no password-reset UI in this v1 (out of scope for tonight's single-demo build; the Mudbase endpoints exist and are documented in the README as a "what's next" note).

## Payment Flow (Mudbase Payment Links — non-custodial stablecoin)
```
Checkout → Next.js Route Handler POST /api/checkout/pay-link
         → creates `orders` doc (status: awaiting_payment) as the signed-in customer
         → server-side, using a merchant-scoped Mudbase session (org owner/admin bearer token,
           held ONLY server-side, never in the client bundle — payment-link creation is an
           org-level owner/admin-only endpoint with no API-key path)
         → POST /api/orgs/:orgId/payment-links { amount, currency, network, redirectUrl }
         → order.paymentLinkToken = link.token; return checkout URL to the browser
Checkout page → renders the Mudbase-hosted payment-link details, polls
              GET /api/payment-links/:token (public, no auth) every few seconds
              → on status "paid": order.paymentStatus = 'paid', order.status = 'paid'
              → on status "expired"/"cancelled": order surfaces a retry action
```
KYC note: Mudbase requires the org to be KYC-approved to create a Payment Link (`requireKycApproved`, re-checked live at creation time). This demo's org KYC state is verified during provisioning (see README "Known limitations") — if not approved, the checkout route surfaces the real `403 KYC_REQUIRED` response as a clear, honest "payments pending verification" state rather than faking a success path.

## UI Pages / Screens
### Home / Catalog — `/`
Components: `ProductGrid`, `CategoryFilter`, `CartButton` (header)
Data: `useDocuments('products', { filter: { isActive: true } })`
Auth guard: public (anonymous session auto-established on first load)

### Product Detail — `/products/[slug]`
Components: `ProductGallery`, `AddToCartForm`
Data: `useDocuments('products', { filter: { slug } })`
Auth guard: public

### Cart — `/cart`
Components: `CartLineItems`, `CartSummary`
Data: `useCart()` (reads/writes the caller's own `carts` doc)
Auth guard: public (anonymous or real account)

### Checkout — `/checkout`
Components: `ShippingForm`, `OrderSummary`
Auth guard: public, but the account-conversion step appears inline if still anonymous
Key interactions: submit shipping details → creates order + payment link → redirects to `/checkout/[token]`

### Payment — `/checkout/[token]`
Components: `PaymentLinkPanel` (address/amount/network, countdown to `expiresAt`), live status poll
Auth guard: public (payment-link public read needs no auth)

### Order History — `/orders`
Components: `OrderList`, `OrderStatusBadge`
Data: `useDocuments('orders', { filter: { userId }, sort: '-createdAt' })`
Auth guard: authenticated (real account only — redirects anonymous users to register/login)

### Order Detail — `/orders/[id]`
Components: `OrderTimeline`, `OrderItemsTable`
Auth guard: authenticated, ownership-enforced server-side

### Auth — `/login`, `/register`
Components: `LoginForm`, `RegisterForm` (role hidden — always `customer`)
Auth guard: public, redirects away if already authenticated

### Seller Dashboard — `/seller`
Components: `SellerOrderQueue` (realtime), `ProductTable`
Data: `useDocuments('orders')` (no ownership filter — seller role) + realtime subscription
Auth guard: `customRole === 'seller'`, else redirect to `/`

### Seller Product Form — `/seller/products/new`, `/seller/products/[id]/edit`
Components: `ProductForm` (name, price, description, category, stock, image upload)
Data: file upload to Mudbase bucket, then `createDocument`/`updateDocument` on `products`
Auth guard: `customRole === 'seller'`

## Security Implementation
- Input validation: zod schemas for every form (register, login, shipping, product form) via react-hook-form + `@hookform/resolvers/zod`.
- Authentication: Mudbase-issued JWT held in memory + `localStorage` via the `MudbaseClient` (matches the platform's own SDK pattern — the token is a project-scoped end-user token, not a platform secret).
- Authorization: enforced server-side by Mudbase collection permissions (ownership conditions on `orders`/`carts`, role-gated CRUD on `products`) — the Next.js app's own role checks (`customRole === 'seller'`) are UX gating only, not the security boundary.
- Rate limiting: inherited from Mudbase's own per-endpoint limits (auth, general API) — no additional app-level limiting needed since there's no custom backend.
- CORS: N/A — the browser talks directly to `cloud.mudbase.dev`, which already enforces its own CORS/allowlist.
- Secrets: `MUDBASE_MERCHANT_REFRESH_TOKEN`/`MUDBASE_MERCHANT_ACCESS_TOKEN` (server-only env vars, used exclusively inside the `/api/checkout/pay-link` Route Handler) — never exposed via `NEXT_PUBLIC_`. `NEXT_PUBLIC_MUDBASE_PROJECT_ID` is the only public value (a project ID is not a secret).

## External Services
CRITICAL:
  - Mudbase project (already provisioned this session) — `NEXT_PUBLIC_MUDBASE_PROJECT_ID`
  - Mudbase merchant session (already minted this session, server-only) — `MUDBASE_MERCHANT_REFRESH_TOKEN`

OPTIONAL:
  - none — Mudbase itself is the entire backend.

## Environment Variables (.env.example)
See `.env.example` in the repo root.

## File Tree
```
mudbase-showcase-ecommerce/
├── package.json
├── tsconfig.json
├── next.config.ts
├── tailwind.config.ts
├── postcss.config.mjs
├── components.json
├── .env.example
├── .eslintrc.json
├── README.md
├── plan/build-plan.md
├── public/
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── globals.css
│   │   ├── page.tsx
│   │   ├── products/[slug]/page.tsx
│   │   ├── cart/page.tsx
│   │   ├── checkout/page.tsx
│   │   ├── checkout/[token]/page.tsx
│   │   ├── orders/page.tsx
│   │   ├── orders/[id]/page.tsx
│   │   ├── login/page.tsx
│   │   ├── register/page.tsx
│   │   ├── seller/page.tsx
│   │   ├── seller/products/new/page.tsx
│   │   ├── seller/products/[id]/edit/page.tsx
│   │   └── api/checkout/pay-link/route.ts
│   ├── components/
│   │   ├── providers/ (QueryProvider, MudbaseProvider wiring)
│   │   ├── layout/ (Header, CartButton)
│   │   ├── catalog/ (ProductGrid, ProductCard, ProductGallery, CategoryFilter)
│   │   ├── cart/ (CartLineItems, CartSummary)
│   │   ├── checkout/ (ShippingForm, OrderSummary, PaymentLinkPanel)
│   │   ├── orders/ (OrderList, OrderStatusBadge, OrderTimeline, OrderItemsTable)
│   │   ├── auth/ (LoginForm, RegisterForm)
│   │   ├── seller/ (SellerOrderQueue, ProductTable, ProductForm)
│   │   └── ui/ (shadcn primitives)
│   ├── hooks/ (useCollection, useCart, useAuth, useRealtimeSubscription, useCollectionRealtime)
│   ├── lib/ (mudbase.ts, mudbase-provider.tsx, utils.ts, json-field.ts)
│   └── types/ (product.ts, order.ts, cart.ts)
```
