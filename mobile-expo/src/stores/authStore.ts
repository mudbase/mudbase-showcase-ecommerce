import { create } from "zustand";
import { mudbaseClient, MudbaseApiError, type RegisterOutcome } from "@/api/client";
import type { MudbaseUser } from "@/api/schemas";

interface AuthState {
  user: MudbaseUser | null;
  /** True only while the boot-time restoreTokens()+getSession() sequence is running. */
  isInitializing: boolean;
  isSubmitting: boolean;
  error: string | null;
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<boolean>;
  registerCustomer: (input: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }) => Promise<RegisterOutcome | null>;
  logout: () => Promise<void>;
  clearError: () => void;
}

function messageFrom(err: unknown, fallback: string): string {
  return err instanceof MudbaseApiError ? err.message : fallback;
}

/**
 * A plain in-memory zustand store, not persisted via MMKV/AsyncStorage — the
 * only durable state is the token pair in SecureStore (mudbaseClient owns
 * that). On cold start, initialize() reloads the token pair and re-derives
 * `user` from a fresh getSession() call, so there is nothing here that could
 * go stale or leak outside the OS keychain.
 */
export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isInitializing: true,
  isSubmitting: false,
  error: null,

  initialize: async (): Promise<void> => {
    set({ isInitializing: true });
    const hasTokens = await mudbaseClient.restoreTokens();
    if (!hasTokens) {
      set({ user: null, isInitializing: false });
      return;
    }
    const user = await mudbaseClient.getSession();
    set({ user, isInitializing: false });
  },

  login: async (email, password): Promise<boolean> => {
    set({ isSubmitting: true, error: null });
    try {
      const user = await mudbaseClient.login(email, password);
      set({ user, isSubmitting: false });
      return true;
    } catch (err) {
      set({ error: messageFrom(err, "Login failed. Check your email and password."), isSubmitting: false });
      return false;
    }
  },

  registerCustomer: async (input): Promise<RegisterOutcome | null> => {
    set({ isSubmitting: true, error: null });
    try {
      const outcome = await mudbaseClient.registerCustomer(input);
      if (outcome.status === "authenticated") {
        set({ user: outcome.user, isSubmitting: false });
      } else {
        set({ isSubmitting: false });
      }
      return outcome;
    } catch (err) {
      set({ error: messageFrom(err, "Registration failed. Please try again."), isSubmitting: false });
      return null;
    }
  },

  logout: async (): Promise<void> => {
    set({ isSubmitting: true });
    await mudbaseClient.logout();
    set({ user: null, isSubmitting: false });
  },

  clearError: (): void => set({ error: null }),
}));
