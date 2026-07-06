from functools import lru_cache
import os
from pathlib import Path

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


def _resolve_env_file() -> str | Path | None:
    env_file = os.environ.get("HUAL_ENV_FILE")
    if env_file is None:
        return Path(__file__).resolve().parents[2] / ".env"
    if env_file == "":
        return None
    return env_file


class Settings(BaseSettings):
    app_name: str = "Hual API"
    version: str = "0.1.0"
    environment: str = "local"
    firebase_project_id: str | None = None
    firebase_service_account_json: str | None = None
    unsplash_access_key: str | None = Field(
        default=None,
        validation_alias=AliasChoices("HUAL_UNSPLASH_ACCESS_KEY", "UNSPLASH_ACCESS_KEY"),
    )
    unsplash_api_base_url: str = "https://api.unsplash.com"
    stripe_secret_key: str | None = None
    stripe_currency: str = "usd"
    groq_api_key: str | None = Field(
        default=None,
        validation_alias=AliasChoices(
            "HUAL_GROQ_API_KEY",
            "GROQ_API_KEY",
            "HUAL_GROK_API_KEY",
            "GROK_API_KEY",
            "HUAL_XAI_API_KEY",
            "XAI_API_KEY",
        ),
    )
    groq_base_url: str = Field(
        default="https://api.groq.com/openai/v1",
        validation_alias=AliasChoices(
            "HUAL_GROQ_BASE_URL",
            "GROQ_BASE_URL",
            "HUAL_GROK_BASE_URL",
            "GROK_BASE_URL",
            "HUAL_XAI_BASE_URL",
            "XAI_BASE_URL",
        ),
    )
    groq_model: str = Field(
        default="meta-llama/llama-4-scout-17b-16e-instruct",
        validation_alias=AliasChoices(
            "HUAL_GROQ_MODEL",
            "GROQ_MODEL",
            "HUAL_GROK_MODEL",
            "GROK_MODEL",
            "HUAL_XAI_MODEL",
            "XAI_MODEL",
        ),
    )
    gemini_api_key: str | None = Field(
        default=None,
        validation_alias=AliasChoices("HUAL_GEMINI_API_KEY", "GEMINI_API_KEY"),
    )
    gemini_model: str = Field(
        default="gemini-2.5-flash",
        validation_alias=AliasChoices("HUAL_GEMINI_MODEL", "GEMINI_MODEL"),
    )
    gemini_disabled: bool = Field(
        default=False,
        description="Operational kill switch used for quota incidents and deterministic fallback verification.",
    )
    catalog_stage_path: str = "backend/seed/products.staged.json"
    catalog_audit_json_path: str = "backend/seed/products.audit.json"
    catalog_audit_md_path: str = "backend/seed/products.audit.md"
    catalog_blueprint_path: str = "backend/seed/catalog_blueprints.json"
    catalog_runs_path: str = "backend/seed/runs"
    catalog_deadline_minutes: int = 30
    catalog_request_timeout_seconds: float = 35.0
    catalog_groq_budget: int = 250
    catalog_gemini_budget: int = 120
    ai_cache_ttl_seconds: int = 900
    hf_space_health_url: str = Field(
        default="https://rana-m-ahmed-haulbackend.hf.space/health",
        description="Used by the keep-warm workflow unless overridden by repository variables.",
    )
    auth_allow_test_tokens: bool = Field(
        default=False,
        description="Local/test-only mode. Never enable in deployed production.",
    )

    model_config = SettingsConfigDict(
        env_prefix="HUAL_",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings(_env_file=_resolve_env_file())
