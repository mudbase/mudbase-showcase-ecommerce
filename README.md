# Mudbase Showcase — Ecommerce

**Live:** https://mudbase-showcase-ecommerce.vercel.app

A production storefront built **entirely on [Mudbase](https://cloud.mudbase.dev)** — auth, database,
realtime, and payments — with **zero custom backend**. This is a reference implementation: every
feature below links to the exact Mudbase capability it exercises, so you can clone it as a starting
point for your own store.

## Stack

Next.js 15 (App Router) + TypeScript + Tailwind + shadcn/ui, talking directly to `cloud.mudbase.dev`
from the browser. The only server-side code in this repo is one Route Handler
(`/api/checkout/pay-link`) — see "Why a Route Handler exists" below.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `src/lib/mudbase-provider.tsx` |
| Customer accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `src/hooks/useAuth.ts` |
| Seller/admin accounts | A second Multi-Role, `seller` (added at provisioning time, no self-signup UI) | see "Provisioning" below |
| Product catalog | Collections, role-scoped read (`authenticated`) + role-scoped write (`seller`) | `src/components/catalog/`, `products` collection |
| Cart, per user | Collections, ownership-conditioned CRUD (`customer` + `{userId: "$userId"}`) | `src/hooks/useCart.ts`, `carts` collection |
| Checkout + orders | Collections, ownership-conditioned create/read/update + unrestricted seller read/update | `src/app/checkout/`, `orders` collection |
| Payments | Payment Links (non-custodial stablecoin, USDC/POLYGON) | `src/lib/mudbase-server.ts`, `src/app/checkout/[token]/` |
| Realtime seller dashboard | Socket.IO `subscribe:collection` + `db:create`/`db:update` | `src/hooks/useOrdersLive.ts` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled.
2. Multi-Role feature initialized with two roles: the default `customer` role, and a custom
   `seller` role (`signupEndpoint: "seller"`, no approval/payment/KYC gate).
3. Three collections — `products`, `orders`, `carts` — with the field/permission shapes documented
   in `plan/build-plan.md`.
4. At least one `seller`-role account to manage the catalog (there's no self-service "become a
   seller" flow in this UI by design — see Known Limitations).

`.env.example` lists every ID this app needs once that's done.

## Known limitations (real platform constraints, not bugs)

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`src/lib/json-field.ts`). This is a documented constraint of the Collections feature, not a
workaround specific to this app.

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard (`enforceServerRoleAssignment.js`) blocks any collection write that includes a `status` key,
for every project end-user regardless of their role or collection permissions — the field name
alone triggers it, with no per-collection opt-out. The `orders` collection's status field is named
`orderStatus` to work around this. Worth flagging back to Mudbase: this blocks a very common
generic-workflow field name platform-wide.

**File uploads require an org owner/admin/developer system role.** `rbacCheck("file", "create")`
only allows those three roles — every project end-user, including a `seller` customRole account, is
permanently a `viewer` system role and gets denied. Product images in this demo are entered as
plain URLs rather than uploaded, because there's no way for the seller to upload one from this app.
A real fix would need either a relaxed file-permission model for end-users or a server-side proxy
that uploads on the seller's behalf using an org-level credential (the same pattern used for payment
links below) — not built here to keep scope to tonight's storefront.

**Why a Route Handler exists at all (`/api/checkout/pay-link`).** Creating a Payment Link
(`POST /api/orgs/:orgId/payment-links`) requires a live org owner/admin bearer token — there is no
API-key path for it, and a project end-user's token can never carry an org role. This route holds a
merchant session (obtained once via `MUDBASE_MERCHANT_REFRESH_TOKEN`, server-only) and calls that
endpoint on the customer's behalf after their order is created client-side under their own account.

**The merchant session's refresh token is single-use and this app is serverless.** Mudbase rotates
refresh tokens on every use. `src/lib/mudbase-server.ts` caches the rotated pair in module scope so
a warm Vercel function instance keeps working, but a cold start always falls back to the seed value
in `MUDBASE_MERCHANT_REFRESH_TOKEN`. If a previous warm instance already rotated past that seed,
refresh fails and checkout returns a clear "payments temporarily unavailable" error rather than
crashing. The real fix is a durable token store (Vercel KV, Upstash, etc.) — deliberately not added
here to keep this demo strictly Mudbase-only; noted as the natural next step for a production
deployment.

**Payment Links require the org to be KYC-approved.** This demo's org was `kycStatus: "none"` at
launch — checkout will surface a real `403 KYC_REQUIRED` as "this store's payments are still
pending identity verification" rather than faking a successful charge. That's the honest behavior
once KYC is completed on the org, not a code change.

## Local development

```bash
npm install
cp .env.example .env.local   # fill in your own provisioned project's IDs
npm run dev
```

## Deploy

Deployed to Vercel. Every env var in `.env.example` must be set as a Production environment
variable in the Vercel project — `MUDBASE_MERCHANT_REFRESH_TOKEN` especially must **never** be
prefixed `NEXT_PUBLIC_` or committed.
