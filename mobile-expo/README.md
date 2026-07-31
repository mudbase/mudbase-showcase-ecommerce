# Mudbase Showcase — Ecommerce (Expo / React Native)

The same storefront as [`../web`](../web), reimplemented against the real
[`mudbase-sdk`](https://github.com/mudbase/mudbase-sdk) JavaScript/TypeScript
client instead of a hand-rolled `fetch` wrapper. Auth, product catalog, cart,
checkout, order history, and a seller dashboard — all backed by a real Mudbase
project, no custom backend of its own.

Stack: Expo (SDK 57) + TypeScript + Expo Router + NativeWind (Tailwind) +
TanStack Query + Zustand + React Hook Form + Zod + `expo-secure-store`.

## Prerequisite: clone the SDK as a sibling directory

The real `mudbase-sdk` has **not** been published to the npm registry — this
app depends on it as a local `file:` path, which means it must exist on disk
at a predictable relative location before `npm install` will succeed.

Clone it **next to** this repo (`mudbase-showcase-ecommerce`), at the same
parent directory level — not inside it:

```
some-parent-directory/
├── mudbase-showcase-ecommerce/     ← this repo (you already have it)
│   └── mobile-expo/                ← you are here
│       └── package.json            ← "mudbase-sdk": "file:../../mudbase-sdk/javascript"
└── mudbase-sdk/                    ← clone this as a sibling
    └── javascript/
```

```bash
# from some-parent-directory/, i.e. one level above mudbase-showcase-ecommerce/
git clone https://github.com/mudbase/mudbase-sdk.git

# the SDK ships as TypeScript source with no committed dist/ — build it once
cd mudbase-sdk/javascript
npm install   # runs its own "prepare" script (tsc), producing dist/
```

The relative path in `mobile-expo/package.json` is `file:../../mudbase-sdk/javascript`
— **two** `../`, not three: one to leave `mobile-expo/`, one more to leave
`mudbase-showcase-ecommerce/`, landing in the parent directory where the SDK's
sibling clone lives. If your clone lives somewhere else, edit that one line
before running `npm install`.

## Setup

```bash
cd mobile-expo
npm install
cp .env.example .env
# fill in your own provisioned Mudbase project's IDs — see plan/build-plan.md
# in ../web for the exact products/orders/carts collection field & permission shapes
npm run start
```

Then press `i` (iOS simulator), `a` (Android emulator), or scan the QR code
with Expo Go / a development build on a physical device.

Env vars are documented in `.env.example`. Every value is read via Expo's
`EXPO_PUBLIC_*` convention (client-bundled, safe — a project/collection ID is
not a secret). Nothing in this app ever holds the org owner/admin credential
required to create Payment Links; see "Payments" below.

## What's implemented

| Feature | Screen(s) | Notes |
|---|---|---|
| Sign up (customer only) / sign in / sign out | `app/(auth)/register.tsx`, `login.tsx`, `app/(tabs)/account.tsx` | Role is hidden and always `customer` for self-signup, matching web — seller accounts are provisioned once, out of band. |
| Product catalog, category filter | `app/(tabs)/index.tsx` | `FlatList` grid, pull-to-refresh via TanStack Query. |
| Product detail, swipeable photo gallery | `app/products/[slug].tsx` | Touch-first equivalent of web's hover-cycle/carousel — see ImageCarousel.tsx. |
| Cart (server-persisted, per user) | `app/(tabs)/cart.tsx` | Customer-role only; see "Deviations" below for why there's no guest cart. |
| Checkout → order → Payment Link | `app/checkout/index.tsx`, `app/checkout/[token].tsx` | Creates the order under the signed-in customer, then calls the web app's payment-link proxy — see "Payments". |
| Order history, order detail, status timeline | `app/(tabs)/orders.tsx`, `app/orders/[id].tsx` | Ownership-filtered by `userId`, same as web. |
| Seller dashboard: order fulfillment queue | `app/seller/index.tsx` | Polls every 5s instead of web's Socket.IO — see "Deviations". |
| Seller product CRUD | `app/seller/index.tsx`, `app/seller/products/new.tsx`, `app/seller/products/[id]/edit.tsx` | Multi-photo gallery via `useFieldArray`, image entered as a URL (see "Known limitations"). |

## SDK dependency — exact mechanism

`src/api/client.ts` instantiates the real generated classes directly — there
is **no** unified client wrapper in `mudbase-sdk` (that's a design choice of
the SDK, not something this app invented around):

```ts
import { AuthenticationApi, MultiRoleFeatureApi, DataApi, Configuration } from "mudbase-sdk";

const configuration = new Configuration({
  basePath: MUDBASE_URL,
  accessToken: async () => this.token ?? "", // re-read on every request — see below
});

const authApi = new AuthenticationApi(configuration);
const multiRoleApi = new MultiRoleFeatureApi(configuration);
const dataApi = new DataApi(configuration);
```

Passing `accessToken` as a **function** (not a static string) to `Configuration`
means the SDK calls it fresh on every request (`setBearerAuthToObject` in the
SDK's `common.ts` awaits it before building each request's `Authorization`
header) — so the same three API instances stay valid across login/logout/token
refresh without ever needing to be recreated.

Methods used, verified against `mudbase-sdk/javascript/docs/*.md` before
writing any code (per this project's docs-fetcher convention — never guess a
third-party API surface):

- `multiRoleApi.registerWithRole("customer", body)` — `POST /api/auth/local/signup/{role}` (`MultiRoleFeatureApi.md`)
- `authApi.loginLocalUser({ email, password, projectId })` — `POST /api/auth/local/login`
- `authApi.getLocalSession(projectId)` — `GET /api/auth/local/session`
- `authApi.logoutLocalUser()` — `POST /api/auth/local/logout`
- `authApi.refreshToken({ refreshToken })` — `POST /api/auth/refresh`
- `dataApi.listData/getData/createData/updateData/deleteData(projectId, collectionId, ...)` — the full Collections CRUD surface (`DataApi.md`)

Two documented gaps in the generated types (both called out with inline
comments at the exact call site in `client.ts`, not silently worked around):

1. **`registerWithRole`'s generated return type is `void`.** The OpenAPI spec
   backing the SDK has no response schema for that operation, even though the
   live endpoint returns the same `{message, token, refreshToken, expiresIn,
   user}` shape `loginLocalUser` does (or `{requireVerification: true}` when
   the project has email verification on). Rather than casting past this with
   `as`, the response is widened to `unknown` (always a legal assignment, zero
   cast needed) and parsed through a Zod schema (`authResultSchema`).
2. **Project-scoped user objects omit `customRole`/`isAnonymous`** in the
   generated models (`LoginLocalUser200ResponseUser`, `GetLocalSession200Response`),
   even though the live API includes them — this app's entire seller-vs-customer
   gating depends on `customRole`, exactly like `web/src/lib/mudbase.ts`'s own
   hand-written `UserObject` interface already documents. Same fix: parse
   through a local Zod schema (`mudbaseUserSchema`) rather than trusting the
   generated type or casting around it.

Also documented in `client.ts`: `RegisterWithRoleRequest`'s generated shape is
missing `agreedToTerms`, a field the registration validator rejects requests
without — a local `RegisterWithRoleRequestBody` interface **extends** (not
replaces) the SDK's own type to add it, keeping clear which parts are
SDK-verified vs. locally documented.

## Payments — delegated to the web app, on purpose

Creating a Mudbase Payment Link (`POST /api/orgs/:orgId/payment-links`)
requires a live **org owner/admin bearer token** — there is no API-key path
for it, and a project end-user's token (everything this app ever holds) can
never carry an org role. That credential must never ship inside a mobile
binary.

So this app never calls that endpoint. When checkout is submitted, it:

1. Creates the `orders` document directly against Mudbase, under the
   signed-in customer's own token (ordinary, ownership-scoped write).
2. `POST`s `{ orderId, amount, currency, network, redirectUrl }` to
   `EXPO_PUBLIC_CHECKOUT_PROXY_URL` — the already-deployed web reference
   app's own `/api/checkout/pay-link` Route Handler, which holds the merchant
   credential server-side and creates the link on this order's behalf.
3. On success, stores the returned `paymentLinkToken` back onto the order and
   navigates to `/checkout/[token]`, which polls the **public**,
   unauthenticated `GET /api/payment-links/:token` endpoint until the link
   reaches a terminal status — same read the web app's own payment screen uses.
4. On `403 { reason: "kyc_required" }`, the order is rolled back to
   `orderStatus: "pending"` and the screen shows an honest "payments pending
   identity verification" message — not a fake success, not a crash.

`redirectUrl` is a real device deep link (`expo-linking`'s `Linking.createURL`,
using this app's own `scheme` in `app.json`), not a web URL — since there's no
browser origin on a phone the way there is on web.

## Deviations from the web version (and why)

**No anonymous/guest browsing.** The web app establishes an anonymous Mudbase
session on first load so a shopper can browse and build a cart before ever
creating an account, then converts that session to a real account at
checkout (`POST /api/auth/anonymous`, `.../anonymous/convert`,
`migrateGuestCartToServer()`). This mobile version requires signing in
(customer or seller) before browsing anything. That's a deliberate
simplification for this reference build, not a platform limitation — Mudbase
fully supports anonymous sessions from a mobile client the same as from a
browser. Requiring login up front removes an entire guest-cart-in-localStorage
+ merge-on-registration code path (`useCart.ts`'s biggest source of complexity
on web) while every other business rule (ownership-scoped cart/orders,
role-gated product writes) stays identical.

**Seller order queue polls instead of using Socket.IO.** Web's seller
dashboard subscribes to the `orders` collection's realtime room
(`useOrdersLive.ts`, `subscribe:collection` + `db:create`/`db:update`) for
instant updates. `socket.io-client` needs extra native polyfills to run
reliably on Hermes/React Native, which wasn't worth the dependency weight for
this reference app — `app/seller/index.tsx` polls every 5 seconds via
TanStack Query's `refetchInterval` instead. Same eventual result, slightly
higher latency, far less to get wrong on a fresh RN + Socket.IO integration.

## Known limitations (real Mudbase platform constraints — same as web)

**Mudbase Collections have no native array/object field type.** Order line
items, shipping addresses, and extra product images are stored as
JSON-encoded strings and parsed at the edges (`src/lib/jsonField.ts`) — a
documented constraint of the Collections feature, not a workaround specific
to this app.

**A field literally named `status` is globally protected.** Mudbase's
server-side role-assignment guard blocks any collection write containing a
`status` key for every project end-user regardless of role or collection
permissions — the field name alone triggers it. The `orders` collection's
status field is named `orderStatus` here for exactly that reason.

**File uploads require an org owner/admin/developer system role.** Every
project end-user, including a `seller` customRole account, is permanently a
`viewer` system role and gets denied on `POST .../buckets/:id/files`. Product
images in this app are entered as plain URLs (`ProductForm.tsx`) rather than
uploaded, same as web — there's no way for a seller to upload one from either
client without a server-side proxy using an org-level credential (the same
pattern used for Payment Links above, not built here for either app).

**No native upsert for the cart.** One `carts` document per user; every write
does a read-then-create-or-update (`useCart.ts`'s `persist` mutation),
re-fetching the authoritative cart immediately before deciding create-vs-update
rather than trusting a stale query-cache value, since Mudbase's Data API has
no PATCH-or-create endpoint.

**Payment Links require the org to be KYC-approved.** Live-verified against
production: checkout creates the order, then the payment-link proxy call
fails — observed as a `502` with `{ reason: "merchant_auth_failed" }` (not
always the `403 KYC_REQUIRED` shape this section originally described; the
proxy can surface either depending on which step of its own org-credential
flow fails). `checkout/index.tsx` rolls the order back to `orderStatus:
"pending"` for **any** failed reason — kyc_required, merchant_auth_failed, or
unknown — not just kyc_required, since leaving it at `awaiting_payment` with
no `paymentLinkToken` would strand the order (no token to navigate to, and
"payment already in progress" from the order's own perspective blocks
re-attempting checkout). Confirmed live: order lands on `pending`, screen
shows the failure message, no crash — the honest behavior, not a bug to fix
here.

**Access tokens are short-lived (~30 min).** `client.ts` retries exactly once
on a `401` by calling `POST /api/auth/refresh` and re-issuing the original
request — refresh tokens rotate on every use per the platform (reuse of an
already-used refresh token revokes the whole session), so concurrent 401s
share a single in-flight refresh promise rather than each firing their own.
Live-verified against production, including the failure edge: when a
refresh token has already been consumed (e.g. by a concurrent session using
the same account), the platform returns `401 Invalid or expired refresh
token` on the refresh call itself. That exception propagates out of
`withAuthRetry` to callers like `getSession()`, whose own catch-all clears
the stored tokens and returns `null` — `AuthGuard` in `app/_layout.tsx` then
treats the user as signed out and redirects to `/login`, not a crash.

**`expo-secure-store` has no real web fallback, despite its own web module's
name.** `ExpoSecureStore.web.ts` in the installed SDK version is a bare
`export default {}` — every method is `undefined` there, not a localStorage
shim. Calling `SecureStore.setItemAsync`/`getItemAsync` under `expo start
--web` threw a client-side `TypeError` before touching storage, silently
breaking login/registration (`persistTokens()` failed on every sign-in) any
time someone ran the local web smoke-test this README recommends below.
Fixed in `src/api/secureStorage.ts`: on `Platform.OS === "web"`, storage now
goes straight to `window.localStorage` instead of through the native-module
shim — making the file's own preexisting comment ("on web it falls back to
localStorage") actually true. Still explicitly not a target platform for
production (no OS keychain in a browser), same as before.

## Local development

```bash
npm install
npx tsc --noEmit      # type-check
npx expo-doctor       # environment / dependency health check
npm run start
```

## Deploy / distribute

Not deployed anywhere by default — this is a client app. Build with
[EAS Build](https://docs.expo.dev/build/introduction/) (`eas build --platform
all --profile production`) once you have your own Apple/Google developer
accounts and have set the `EXPO_PUBLIC_*` env vars in your EAS build profile
(`eas.json`), matching `.env.example`.
