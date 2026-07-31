import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

/**
 * Auth tokens live here, never in AsyncStorage/MMKV — a hard security rule for
 * this project (see CLAUDE.md "Mobile" security non-negotiables). SecureStore
 * wraps iOS Keychain / Android Keystore. On web, `expo-secure-store`'s own
 * `ExpoSecureStore.web.ts` module is a bare `export default {}` — every method
 * is `undefined` there, not a localStorage shim — so calling
 * `SecureStore.setItemAsync`/`getItemAsync` on web throws a client-side
 * TypeError before anything reaches storage. That silently broke login and
 * registration under `expo start --web`, since `persistTokens()` would throw
 * on every sign-in. `IS_WEB` below routes storage straight to
 * `window.localStorage` instead of through the native-module shim, which is
 * what this file's own comment already claimed happened — it just didn't.
 * Still not a target platform for production (web has no OS keychain), so
 * this is explicitly a local-smoke-test / QA-only fallback, same as before.
 */
const IS_WEB = Platform.OS === "web";

if (IS_WEB) {
  // eslint-disable-next-line no-console
  console.warn("[secureStorage] Running on web — falling back to localStorage, not secure for production.");
}

const SECURE_STORE_OPTIONS: SecureStore.SecureStoreOptions = {
  keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
};

export const STORAGE_KEYS = {
  ACCESS_TOKEN: "mudbase.accessToken",
  REFRESH_TOKEN: "mudbase.refreshToken",
} as const;

export const secureStorage = {
  async set(key: string, value: string): Promise<void> {
    if (IS_WEB) {
      try {
        window.localStorage.setItem(key, value);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        throw new Error(`localStorage write failed for key "${key}": ${message}`);
      }
      return;
    }
    try {
      await SecureStore.setItemAsync(key, value, SECURE_STORE_OPTIONS);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`SecureStore write failed for key "${key}": ${message}`);
    }
  },

  async get(key: string): Promise<string | null> {
    if (IS_WEB) {
      try {
        return window.localStorage.getItem(key);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        // eslint-disable-next-line no-console
        console.warn(`[secureStorage] Failed to read key "${key}": ${message}`);
        return null;
      }
    }
    try {
      return await SecureStore.getItemAsync(key, SECURE_STORE_OPTIONS);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      // eslint-disable-next-line no-console
      console.warn(`[secureStorage] Failed to read key "${key}": ${message}`);
      return null;
    }
  },

  async delete(key: string): Promise<void> {
    if (IS_WEB) {
      try {
        window.localStorage.removeItem(key);
      } catch {
        // Key may already be absent — not an error condition worth surfacing.
      }
      return;
    }
    try {
      await SecureStore.deleteItemAsync(key, SECURE_STORE_OPTIONS);
    } catch {
      // Key may already be absent — not an error condition worth surfacing.
    }
  },
};
