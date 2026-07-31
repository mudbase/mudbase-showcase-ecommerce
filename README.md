# Mudbase Showcase — Ecommerce

A production storefront built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database,
realtime, and payments — with **zero custom backend**. The same store, reimplemented once per
official Mudbase SDK, so every supported language has a real, runnable reference app rather than a
toy snippet.

Every version talks to the same Mudbase project shape (see `web/plan/build-plan.md` for the
collection/permission schema) and demonstrates the same feature set: product catalog, cart,
checkout, orders, and a seller dashboard.

## Versions in this repo

| Directory | Platform | SDK |
|---|---|---|
| [`web/`](./web) | Next.js 15 (App Router) web app | JavaScript/TypeScript |
| [`mobile-expo/`](./mobile-expo) | Expo / React Native mobile app | JavaScript/TypeScript |
| [`mobile-flutter/`](./mobile-flutter) | Flutter mobile app | Dart |
| [`python/`](./python) | Server-rendered web app | Python |
| [`go/`](./go) | Server-rendered web app | Go |
| [`ruby/`](./ruby) | Server-rendered web app | Ruby |
| [`java/`](./java) | Server-rendered web app (Spring Boot) | Java |
| [`csharp/`](./csharp) | Server-rendered web app (ASP.NET Core) | C# |
| [`php/`](./php) | Server-rendered web app | PHP |
| [`swift/`](./swift) | iOS app (SwiftUI) | Swift |

Each directory is self-contained with its own README, dependency manifest, and `.env.example` —
clone this repo and only set up the language you care about.

## Prerequisite: clone the SDK repo as a sibling

Most versions here (everything except `python/`, `go/`, and `ruby/`, whose package managers can
install straight from a git subdirectory) reference the [mudbase-sdk](https://github.com/mudbase/mudbase-sdk)
repo by relative path, since none of the 9 SDKs are published to a public registry yet. Clone it
next to this repo, at the same parent directory level, before building any version besides `web/`:

```
some-folder/
├── mudbase-sdk/                  # git clone https://github.com/mudbase/mudbase-sdk
└── mudbase-showcase-ecommerce/   # this repo
```

`swift/` needs one extra step: because its own directory and the SDK's `swift/` subdirectory share
a basename, Swift Package Manager needs a distinctly-named path to resolve — this repo ships a
committed symlink (`mudbase-sdk-swift → ../mudbase-sdk/swift`) at the root for exactly that reason.

## Why one repo

All ten versions are the same product against the same API, so keeping them side by side makes it
easy to compare how the same auth flow, cart mutation, or checkout call looks across languages —
and to keep them all honest against the real [Mudbase SDKs](https://github.com/mudbase/mudbase-sdk)
as the API evolves.

## License

[MIT](./LICENSE)
