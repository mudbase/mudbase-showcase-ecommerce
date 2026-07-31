# Mudbase Showcase — Ecommerce (C# / ASP.NET Core)

A server-rendered storefront built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and payments — using ASP.NET Core Razor Pages and the real, generated
[Mudbase C# SDK](https://github.com/mudbase/mudbase-sdk). This is a C# reimplementation of the
reference storefront that also exists at `../web` (Next.js) in this same monorepo — same Mudbase
project, same collections, same business logic, different stack.

## Stack

ASP.NET Core 8 (Razor Pages, not MVC — simpler and idiomatic for a page-per-flow demo like this) +
the real `Mudbase.Sdk` package (referenced as a sibling project, not from NuGet — see "Setup"
below). Server-side session (`Microsoft.AspNetCore.Session`) holds the Mudbase JWT; it is never
sent to client JS. Bootstrap 5 (via CDN) for styling — no build step, no Node.js required.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `Services/MudbaseAuthService.cs` (`EnsureAnonymousSessionAsync`), bootstrapped by `Infrastructure/EnsureMudbaseSessionMiddleware.cs` |
| Customer accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `Services/MudbaseAuthService.cs` (`RegisterCustomerAsync`) |
| Seller/admin accounts | A second Multi-Role, `seller` (provisioned out-of-band, no self-signup UI) | `Pages/Seller/*` gated on `MudbaseSessionUser.IsSeller` |
| Product catalog | Collections, role-scoped read (`authenticated`) + role-scoped write (`seller`) | `Pages/Index.cshtml(.cs)`, `Pages/Products/Detail.cshtml(.cs)`, `products` collection |
| Multi-photo gallery + discounts | JSON-string field (`galleryJson`) for the array Collections can't natively store, plus a plain `compareAtPriceCents` number field | `Services/JsonFieldHelper.cs`, `Pages/Seller/Products/_ProductForm.cshtml` |
| Cart, per user | Collections, ownership-conditioned CRUD (`customer` + `{userId: "$userId"}`) | `Services/CartService.cs`, `carts` collection |
| Checkout + orders | Collections, ownership-conditioned create/read/update + unrestricted seller read/update | `Pages/Checkout/*`, `Pages/Orders/*`, `orders` collection |
| Payments | Payment Links (non-custodial stablecoin, USDC/POLYGON) | `Services/PaymentLinkProxyService.cs`, `Pages/Checkout/Pay.cshtml(.cs)` |
| Seller fulfillment queue | `orders` collection, unrestricted seller read/update | `Pages/Seller/Index.cshtml(.cs)` (polled/refresh-based — see "Known limitations", no realtime port) |

## Setup

### 1. Clone the SDK as a sibling directory

The `.csproj` references the real Mudbase C# SDK via a relative `<ProjectReference>` — it is
**not published to NuGet**. It must be cloned as a sibling of `mudbase-showcase-ecommerce` (the
repo this `csharp/` folder lives in), i.e.:

```
<some-parent-directory>/
├── mudbase-showcase-ecommerce/     ← this repo (you are in csharp/ inside it)
└── mudbase-sdk/                    ← clone this next to it
```

```bash
cd <the directory containing mudbase-showcase-ecommerce>
git clone https://github.com/mudbase/mudbase-sdk.git
```

### 2. Provision a Mudbase project

This app expects a Mudbase project already set up with (same requirements as `../web`):

1. Local auth enabled.
2. Multi-Role feature initialized with two roles: the default `customer` role, and a custom
   `seller` role (`signupEndpoint: "seller"`, no approval/payment/KYC gate).
3. Three collections — `products`, `orders`, `carts` — with the field/permission shapes documented
   in `../web/plan/build-plan.md`.
4. At least one `seller`-role account to manage the catalog (there's no self-service "become a
   seller" flow in this UI by design — see Known Limitations).

### 3. Configure

```bash
cp appsettings.Example.json /dev/null  # just to read it — see the file for every key
```

Copy the `Mudbase` section from `appsettings.Example.json` into
`MudbaseShowcase.Ecommerce/appsettings.Development.json`, filling in your own project's IDs. In
production, set the equivalent `Mudbase__<Key>` environment variables (e.g.
`Mudbase__ProjectId=...`) instead of committing real values.

### 4. Build and run

```bash
cd MudbaseShowcase.Ecommerce
dotnet build
dotnet run
```

The app fails fast at startup with a clear message if any required `Mudbase:*` config value is
missing — see `Options/MudbaseOptions.cs`.

## Payment flow

Creating a Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live org owner/admin
bearer token — there is no API-key path for it, and a project end-user's JWT (customer or seller)
can never carry an org role. To avoid every per-language reimplementation of this reference
storefront independently rotating the same single-use merchant refresh token (a real race
condition if multiple apps run concurrently), **this app does not create payment links itself**.

Instead, `Services/PaymentLinkProxyService.cs` calls the already-deployed Next.js reference app's
own proxy route: `POST https://mudbase-showcase-ecommerce.vercel.app/api/checkout/pay-link` with
`{ orderId, amount, currency, network, redirectUrl }`. That route holds the merchant credential
(see `../web/src/lib/mudbase-server.ts`) and creates the link on the customer's behalf, after their
order is created directly under their own account by this app. A `403` with `reason: "kyc_required"`
is surfaced honestly as "payments pending identity verification," not faked as a success.

The payment status page (`Pages/Checkout/Pay.cshtml(.cs)`) polls the **public, unauthenticated**
`GET /api/payment-links/:token` directly against Mudbase (no proxy needed for reads) every 4
seconds via a small vanilla-JS `fetch` loop hitting this page's own `OnGetStatus` handler, until the
link reaches a terminal status (paid/expired/cancelled).

## Known limitations (real platform constraints, not bugs)

**Mudbase Collections have no native array/object field type.** Order line items, shipping
addresses, and extra product images are stored as JSON-encoded strings and parsed at the edges
(`Services/JsonFieldHelper.cs`). This is a documented constraint of the Collections feature, not a
workaround specific to this app.

**A field literally named `status` is globally protected.** Mudbase's server-side role-assignment
guard blocks any collection write that includes a `status` key, for every project end-user
regardless of role or collection permissions — the field name alone triggers it. The `orders`
collection's status field is named `orderStatus` to work around this (see `Models/OrderDocument.cs`).

**File uploads require an org owner/admin/developer system role.** Every project end-user,
including a `seller` customRole account, is permanently a `viewer` system role and gets denied.
Product images in this demo are entered as plain URLs rather than uploaded — see
`Pages/Seller/Products/_ProductForm.cshtml`.

**Registration bypasses the generated SDK for one endpoint.** The generated
`MultiRoleFeatureApi.RegisterWithRoleAsync` models `POST /api/auth/local/signup/:role`'s request as
only `email`/`password`/`firstName`/`lastName`/`projectId` (no `agreedToTerms`, which the live
validator actually requires), and its response as `void` (the OpenAPI spec this SDK was generated
from left the response schema unspecified). Rather than send a request guaranteed to be rejected, or
fabricate a nonexistent SDK method, `Services/MudbaseAuthService.RegisterCustomerAsync` calls that
one endpoint directly via a plain `HttpClient` bound to the same Mudbase base URL, and parses the
response body itself. Every other Mudbase call in this app goes through the generated SDK.

**The generated SDK's token pipeline assumes one static token per app.** `HostConfiguration.AddTokens`
+ `UseProvider` are built for a server-to-server API key registered once at startup — this app has
many concurrent browser sessions, each with its own Mudbase JWT (anonymous guest, customer, or
seller) that changes over the app's lifetime. `Services/SessionBearerTokenProvider.cs` overrides the
SDK's `TokenProvider<BearerToken>` to resolve whichever JWT the *current* request's session holds,
via `IHttpContextAccessor` — see that file's doc comment for the full reasoning. This is the one
piece of DI plumbing in this app that isn't just "call the generated method"; everything else is.

**No realtime seller dashboard.** The reference Next.js app subscribes to Mudbase's Socket.IO
`db:create`/`db:update` events so new orders appear on the seller dashboard instantly. Porting a
persistent Socket.IO client connection into a stateless, server-rendered Razor Pages request cycle
is a meaningfully different architecture (a background service + SignalR bridge to the browser, at
minimum) and was out of scope here. `Pages/Seller/Index.cshtml(.cs)` instead reloads on page
visit and via an explicit "Refresh" link.

**The merchant session's refresh token is single-use and the proxy is someone else's deployment.**
Same constraint as `../web`'s own README describes for its `/api/checkout/pay-link` route — this
app is simply a client of that proxy, so the constraint applies transitively. If the proxy's merchant
session has an issue, this app surfaces "Couldn't start payment. Please try again." rather than a
raw error.

**Payment Links require the org to be KYC-approved.** If the underlying org's `kycStatus` isn't
approved, checkout surfaces a real `403 KYC_REQUIRED` as "this store's payments are still pending
identity verification" rather than faking a successful charge.

## Project layout

```
MudbaseShowcase.Ecommerce/
├── Program.cs                    ← DI wiring, incl. the Mudbase SDK's own DI extensions
├── appsettings.json               ← non-secret defaults + empty Mudbase:* placeholders
├── Options/MudbaseOptions.cs      ← strongly-typed config, fail-fast validation
├── Models/                        ← ProductDocument, OrderDocument, CartDocument, etc.
├── Services/                      ← MudbaseDataService (generic CRUD), MudbaseAuthService,
│                                     CartService, PaymentLinkProxyService, JSON/session helpers
├── Infrastructure/                ← EnsureMudbaseSessionMiddleware (anonymous session bootstrap)
└── Pages/                         ← one folder per flow: Products, Cart, Checkout, Orders, Seller
```

## Verification

`dotnet build` passes with 0 errors, 0 warnings against the real `Mudbase.Sdk` project reference
(net8.0, `Nullable` enabled). This was additionally smoke-tested end-to-end at runtime against the
live `https://cloud.mudbase.dev` API using a placeholder (non-existent) project ID: every page
renders correctly and every Mudbase call — including the anonymous session bootstrap, catalog
reads, the raw signup-with-role call, and the public payment-link status read — round-trips real
HTTP requests/responses and surfaces Mudbase's real error messages as friendly page text instead of
crashing, since a real project's IDs weren't available in this environment. No Mudbase project or
API key was available to test a fully successful checkout end-to-end.
