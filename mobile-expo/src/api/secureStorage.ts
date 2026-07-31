import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

/**
 * Auth tokens live here, never in AsyncStorage/MMKV — a hard security rule for
 * this project (see CLAUDE.md "Mobile" security non-negotiables). SecureStore
 * wraps iOS Keychain / Android Keystore; on web it falls back to localStorage,
 * which is fine for local `expo start --web` smoke-testing but not a target
 * platform for this app (Mudbase itself has no browser-storage guidance to add
 * on top of that fallback).
 */
if (Platform.OS === "web") {
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
    try {
      await SecureStore.setItemAsync(key, value, SECURE_STORE_OPTIONS);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`SecureStore write failed for key "${key}": ${message}`);
    }
  },

  async get(key: string): Promise<string | null> {
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
    try {
      await SecureStore.deleteItemAsync(key, SECURE_STORE_OPTIONS);
    } catch {
      // Key may already be absent — not an error condition worth surfacing.
    }
  },
};
