"""Environment configuration.

Mirrors web/src/lib/config.ts: fail fast at startup if a required collection/
project ID is missing, rather than surfacing a confusing error deep inside a
request handler later.
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mudbase_url: str = Field(default="https://cloud.mudbase.dev", alias="MUDBASE_URL")
    mudbase_project_id: str = Field(alias="MUDBASE_PROJECT_ID")
    products_collection_id: str = Field(alias="PRODUCTS_COLLECTION_ID")
    orders_collection_id: str = Field(alias="ORDERS_COLLECTION_ID")
    carts_collection_id: str = Field(alias="CARTS_COLLECTION_ID")

    session_secret_key: str = Field(alias="SESSION_SECRET_KEY")
    session_cookie_name: str = Field(default="mudbase_showcase_session", alias="SESSION_COOKIE_NAME")
    session_https_only: bool = Field(default=False, alias="SESSION_HTTPS_ONLY")

    pay_link_proxy_url: str = Field(
        default="https://mudbase-showcase-ecommerce.vercel.app/api/checkout/pay-link",
        alias="PAY_LINK_PROXY_URL",
    )
    app_base_url: str = Field(default="http://localhost:8000", alias="APP_BASE_URL")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached so env parsing/validation happens once per process, not per request."""
    return Settings()  # type: ignore[call-arg]  # values come from the environment/.env file
