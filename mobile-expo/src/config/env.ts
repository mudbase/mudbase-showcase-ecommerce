/**
 * All values here are read from EXPO_PUBLIC_* env vars — Expo's convention for
 * anything safe to bundle into the client binary (a project ID or collection ID
 * is not a secret; see mobile-app/SKILL.md "Configuration"). The one credential
 * that must never live here — the org owner/admin bearer session used to mint
 * Mudbase Payment Links — stays server-side inside the web app's Route Handler;
 * this app only ever calls that proxy over HTTPS (see checkoutClient.ts).
 */
function requireEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. Copy .env.example to .env and fill in your provisioned Mudbase project's IDs.`,
    );
  }
  return value;
}

export const MUDBASE_URL = process.env.EXPO_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev";

export const MUDBASE_PROJECT_ID = requireEnv(
  "EXPO_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.EXPO_PUBLIC_MUDBASE_PROJECT_ID,
);

export const PRODUCTS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_PRODUCTS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_PRODUCTS_COLLECTION_ID,
);

export const ORDERS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_ORDERS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_ORDERS_COLLECTION_ID,
);

export const CARTS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_CARTS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_CARTS_COLLECTION_ID,
);

export const CHECKOUT_PROXY_URL = requireEnv(
  "EXPO_PUBLIC_CHECKOUT_PROXY_URL",
  process.env.EXPO_PUBLIC_CHECKOUT_PROXY_URL,
);
