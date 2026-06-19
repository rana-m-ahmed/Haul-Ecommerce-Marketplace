from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import pytest
import yaml
from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[3]
CONTRACT_PATH = ROOT / "progress" / "01_API_CONTRACT.yaml"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


@pytest.fixture(scope="session")
def contract() -> dict[str, Any]:
    with CONTRACT_PATH.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("HUAL_AUTH_ALLOW_TEST_TOKENS", "true")
    from backend.app.core.config import get_settings
    from backend.app.api.v1.dependencies import get_ai_service, get_cart_service, get_catalog_service, get_event_service
    from backend.app.services.event_repository import LocalEventRepository

    get_settings.cache_clear()
    get_ai_service.cache_clear()
    get_cart_service.cache_clear()
    get_catalog_service.cache_clear()
    get_event_service.cache_clear()
    LocalEventRepository._events = {}
    LocalEventRepository._cache = {}
    LocalEventRepository._users = {"u_001": {"isGuest": False, "preferences": ["home", "minimal", "warm"]}}
    from backend.app.main import create_app

    return TestClient(create_app())
