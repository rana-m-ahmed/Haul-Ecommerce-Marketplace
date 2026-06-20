from __future__ import annotations

from backend.app.core.config import get_settings


def test_settings_load_backend_env_from_repo_root(monkeypatch) -> None:
    monkeypatch.delenv("HUAL_FIREBASE_PROJECT_ID", raising=False)
    monkeypatch.delenv("HUAL_FIREBASE_SERVICE_ACCOUNT_JSON", raising=False)
    monkeypatch.delenv("HUAL_STRIPE_SECRET_KEY", raising=False)
    monkeypatch.delenv("HUAL_AUTH_ALLOW_TEST_TOKENS", raising=False)

    get_settings.cache_clear()
    settings = get_settings()

    assert settings.firebase_project_id
    assert settings.firebase_service_account_json
    assert settings.stripe_secret_key
    assert settings.auth_allow_test_tokens is True
