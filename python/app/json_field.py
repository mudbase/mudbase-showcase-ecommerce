"""JSON-string field helpers.

Mirrors web/src/lib/json-field.ts: Mudbase Collection fields have a fixed type
enum (string, number, boolean, date, email, url, enum, reference) with no
native array/object type. Anything shaped like a list or a nested record
(order line items, a shipping address, extra product images) is stored as a
JSON string in a `string` field and parsed at the edges. Real, documented
platform constraint — not a workaround specific to this app.
"""

import json
from typing import Any, TypeVar, cast

T = TypeVar("T")


def parse_json_field(value: str | None, fallback: T) -> T:
    """Parses a JSON-encoded string field, falling back on missing/invalid input.

    `T` is inferred from `fallback`; the parsed JSON is trusted to match it
    (the shape is controlled entirely by this app's own writes) rather than
    validated here — callers that build a Pydantic model from the result
    (e.g. `Order.items`) get that validation for free at that point instead.
    """
    if not value:
        return fallback
    try:
        return cast(T, json.loads(value))
    except (ValueError, TypeError):
        return fallback


def stringify_json_field(value: Any) -> str:
    """Encodes a value for storage in a JSON-string collection field."""
    return json.dumps(value)
