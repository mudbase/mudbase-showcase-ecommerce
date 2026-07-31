export function formatMoney(cents: number, currency = "USD"): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(cents / 100);
}

export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeStyle: "short" }).format(new Date(iso));
}

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export function discountPercent(priceCents: number, compareAtPriceCents?: number): number | null {
  if (!compareAtPriceCents || compareAtPriceCents <= priceCents) return null;
  return Math.round((1 - priceCents / compareAtPriceCents) * 100);
}

export function orderShortId(id: string): string {
  return id.slice(-6).toUpperCase();
}
