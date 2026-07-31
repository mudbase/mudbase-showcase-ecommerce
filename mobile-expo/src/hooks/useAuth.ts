import { useAuthStore } from "@/stores/authStore";
import type { RegisterOutcome } from "@/api/client";
import type { MudbaseUser } from "@/api/schemas";

interface UseAuthReturn {
  user: MudbaseUser | null;
  isInitializing: boolean;
  isSubmitting: boolean;
  error: string | null;
  isCustomer: boolean;
  isSeller: boolean;
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

/** Thin selector hook over the auth store — screens read/act through this, never the store directly. */
export function useAuth(): UseAuthReturn {
  const user = useAuthStore((s) => s.user);
  const isInitializing = useAuthStore((s) => s.isInitializing);
  const isSubmitting = useAuthStore((s) => s.isSubmitting);
  const error = useAuthStore((s) => s.error);
  const login = useAuthStore((s) => s.login);
  const registerCustomer = useAuthStore((s) => s.registerCustomer);
  const logout = useAuthStore((s) => s.logout);
  const clearError = useAuthStore((s) => s.clearError);

  return {
    user,
    isInitializing,
    isSubmitting,
    error,
    isCustomer: user?.customRole === "customer",
    isSeller: user?.customRole === "seller",
    login,
    registerCustomer,
    logout,
    clearError,
  };
}
