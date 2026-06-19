from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Hual API"
    version: str = "0.1.0"
    environment: str = "local"
    firebase_project_id: str | None = None
    firebase_service_account_json: str | None = None
    stripe_secret_key: str | None = None
    gemini_api_key: str | None = None
    gemini_disabled: bool = Field(
        default=False,
        description="Operational kill switch used for quota incidents and deterministic fallback verification.",
    )
    ai_cache_ttl_seconds: int = 900
    hf_space_health_url: str = Field(
        default="https://hual-api.hf.space/health",
        description="Used by the keep-warm workflow unless overridden by repository variables.",
    )
    auth_allow_test_tokens: bool = Field(
        default=False,
        description="Local/test-only mode. Never enable in deployed production.",
    )

    model_config = SettingsConfigDict(env_prefix="HUAL_", env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
