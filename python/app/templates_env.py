"""Shared Jinja2Templates instance + custom filters, importable by every
router without risking a circular import with main.py."""

from pathlib import Path

from fastapi.templating import Jinja2Templates

from app.utils import discount_percent, format_date, format_money, short_order_id

TEMPLATES_DIR = Path(__file__).parent / "templates"

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))
templates.env.filters["money"] = format_money
templates.env.filters["date"] = format_date
templates.env.filters["discount_percent"] = discount_percent
templates.env.globals["short_order_id"] = short_order_id
