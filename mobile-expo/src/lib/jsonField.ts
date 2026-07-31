/**
 * Mudbase Collection fields have a fixed type enum (string, number, boolean,
 * date, email, url, enum, reference) with no native array/object type.
 * Anything shaped like a list or a nested record (order line items, a
 * shipping address, extra product images) is stored as a JSON string in a
 * `string` field and parsed at the edges — a real, documented constraint of
 * the platform's Collections feature (see web/README.md "Known limitations"),
 * not a workaround specific to this app.
 */
export function parseJsonField<T>(value: string | undefined | null, fallback: T): T {
  if (!value) return fallback;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
}

export function stringifyJsonField<T>(value: T): string {
  return JSON.stringify(value);
}
