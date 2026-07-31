"""FastAPI application factory. Run with:
    uvicorn app.main:app --reload
"""

import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware

from app.config import get_settings
from app.routers import auth, cart, catalog, checkout, orders, seller

STATIC_DIR = Path(__file__).parent / "static"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Mudbase Showcase — Ecommerce (Python)",
        description=(
            "Server-rendered FastAPI + Jinja2 reimplementation of the Mudbase "
            "showcase storefront, backed entirely by the real Mudbase Python SDK."
        ),
    )

    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.session_secret_key,
        session_cookie=settings.session_cookie_name,
        https_only=settings.session_https_only,
        same_site="lax",
    )

    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

    app.include_router(catalog.router)
    app.include_router(auth.router)
    app.include_router(cart.router)
    app.include_router(checkout.router)
    app.include_router(orders.router)
    app.include_router(seller.router)

    return app


app = create_app()
