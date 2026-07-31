import { useEffect, useState, useCallback } from "react";
import { MUDBASE_URL } from "@/config/env";
import { publicPaymentLinkSchema, type PublicPaymentLink } from "@/api/schemas";

interface UsePaymentLinkStatusReturn {
  link: PublicPaymentLink | null;
  loading: boolean;
  error: string | null;
}

const DEFAULT_POLL_INTERVAL_MS = 4000;

/**
 * Public, unauthenticated read (GET /api/payment-links/:token) — polls until
 * the link reaches a terminal status. No SDK method exists for this endpoint
 * (it is intentionally outside the authenticated Data/Auth APIs so a shopper
 * can check payment status without any Mudbase session), so this hook calls
 * it directly with fetch, exactly like web/src/hooks/usePaymentLinkStatus.ts.
 */
export function usePaymentLinkStatus(
  token: string,
  intervalMs: number = DEFAULT_POLL_INTERVAL_MS,
): UsePaymentLinkStatusReturn {
  const [link, setLink] = useState<PublicPaymentLink | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOnce = useCallback(async (): Promise<PublicPaymentLink> => {
    const res = await fetch(`${MUDBASE_URL}/api/payment-links/${token}`);
    if (!res.ok) {
      const body = (await res.json().catch(() => ({}))) as { error?: string };
      throw new Error(body.error ?? "Payment link not available");
    }
    const body = (await res.json()) as { link: unknown };
    return publicPaymentLinkSchema.parse(body.link);
  }, [token]);

  useEffect(() => {
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | null = null;

    const tick = async (): Promise<void> => {
      try {
        const result = await fetchOnce();
        if (cancelled) return;
        setLink(result);
        setError(null);
        setLoading(false);
        if (result.status === "pending") {
          timer = setTimeout(() => void tick(), intervalMs);
        }
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Couldn't check payment status");
        setLoading(false);
        timer = setTimeout(() => void tick(), intervalMs);
      }
    };

    void tick();
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [fetchOnce, intervalMs]);

  return { link, loading, error };
}
