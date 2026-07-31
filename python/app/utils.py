"""Small formatting helpers. Mirrors web/src/lib/utils.ts."""

import random
import re
import string
from datetime import datetime
from typing import Final

_SLUG_STRIP_RE: Final = re.compile(r"[^a-z0-9]+")
_SLUG_TRIM_RE: Final = re.compile(r"(^-|-$)")
_SLUG_SUFFIX_ALPHABET: Final = string.digits + string.ascii_lowercase


def format_money(cents: int, currency: str = "USD") -> str:
    """Formats integer cents as a currency string (e.g. 1999 -> "$19.99")."""
    amount = cents / 100
    symbol = "$" if currency.upper() == "USD" else f"{currency.upper()} "
    return f"{symbol}{amount:,.2f}"


def format_date(value: datetime | str | None) -> str:
    """Formats an ISO timestamp (or already-parsed datetime) for display."""
    if value is None:
        return ""
    parsed: datetime
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    else:
        parsed = value
    return parsed.strftime("%b %-d, %Y, %-I:%M %p")


def slugify(value: str) -> str:
    """Lowercases, strips non-alphanumerics to hyphens, trims leading/trailing hyphens."""
    lowered = value.lower().strip()
    hyphenated = _SLUG_STRIP_RE.sub("-", lowered)
    return _SLUG_TRIM_RE.sub("", hyphenated)


def random_slug_suffix(length: int = 6) -> str:
    """Base36-ish random suffix, matching Math.random().toString(36).slice(2, 8) in the web app."""
    return "".join(random.choices(_SLUG_SUFFIX_ALPHABET, k=length))


def discount_percent(price_cents: int, compare_at_price_cents: int | None) -> int | None:
    """Returns the whole-percent discount, or None when there is no valid markdown."""
    if not compare_at_price_cents or compare_at_price_cents <= price_cents:
        return None
    return round((1 - price_cents / compare_at_price_cents) * 100)


def short_order_id(order_id: str) -> str:
    """Last 6 chars, uppercased — matches order._id.slice(-6).toUpperCase() in the web app."""
    return order_id[-6:].upper()
