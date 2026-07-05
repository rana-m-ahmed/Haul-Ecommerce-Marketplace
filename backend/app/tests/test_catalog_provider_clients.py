from __future__ import annotations

from types import SimpleNamespace

import httpx
import pytest

from backend.app.core.gemini_client import GeminiClient
from backend.app.core.groq_client import GroqClient


def _settings():
    return SimpleNamespace(
        groq_api_key="test-groq",
        groq_base_url="https://groq.test/v1",
        groq_model="vision-model",
        gemini_api_key="test-gemini",
        gemini_disabled=False,
        gemini_model="gemini-configured-model",
        catalog_request_timeout_seconds=1.0,
    )


@pytest.mark.asyncio
async def test_groq_retries_only_retryable_statuses(monkeypatch) -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(429, request=request, headers={"retry-after": "0"}, text="limited")
        return httpx.Response(200, request=request, json={"choices": [{"message": {"content": '{"ok":true}'}}]})

    async def no_sleep(_seconds: float) -> None:
        return None

    monkeypatch.setattr("backend.app.core.groq_client.asyncio.sleep", no_sleep)
    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = GroqClient(_settings(), client=http_client)
    payload = await client._generate_json(
        prompt="probe",
        schema={"type": "object", "required": ["ok"], "properties": {"ok": {"type": "boolean"}}},
    )
    await http_client.aclose()

    assert payload == {"ok": True}
    assert calls == 2


@pytest.mark.asyncio
async def test_groq_does_not_retry_permanent_client_error() -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(400, request=request, text="bad schema")

    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = GroqClient(_settings(), client=http_client)
    with pytest.raises(httpx.HTTPStatusError):
        await client._generate_json(prompt="probe", schema={"type": "object"})
    await http_client.aclose()

    assert calls == 1


@pytest.mark.asyncio
async def test_groq_catalog_review_falls_back_to_text_on_vision_rate_limit(monkeypatch) -> None:
    requests: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        import json

        body = json.loads(request.content)
        requests.append(body)
        content = body["messages"][0]["content"]
        if any(item.get("type") == "image_url" for item in content):
            return httpx.Response(429, request=request, headers={"retry-after": "0"}, text="vision limited")
        payload = {
            "name": "White Table Lamp", "description": "A white ceramic table lamp.", "category": "home",
            "objectType": "table lamp", "colors": ["white"], "materials": ["ceramic"],
            "style": ["minimal"], "tags": ["lamp"], "confidence": 0.85,
            "rejectionReasons": [], "heroImageSuitable": True,
        }
        return httpx.Response(200, request=request, json={"choices": [{"message": {"content": json.dumps(payload)}}]})

    async def no_sleep(_seconds: float) -> None:
        return None

    monkeypatch.setattr("backend.app.core.groq_client.asyncio.sleep", no_sleep)
    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = GroqClient(_settings(), client=http_client)
    review = await client.review_catalog_candidate(
        image_url="https://images.test/lamp.jpg",
        brief={"category": "home", "concept": "ceramic table lamp"},
        photo_context={"altDescription": "white table lamp"},
    )
    await http_client.aclose()

    assert review["objectType"] == "table lamp"
    assert len(requests) == 2
    assert all(item.get("type") != "image_url" for item in requests[1]["messages"][0]["content"])


@pytest.mark.asyncio
async def test_gemini_uses_configured_model(monkeypatch) -> None:
    requested_models: list[str] = []

    class FakeModels:
        def generate_content(self, *, model, contents, config):
            requested_models.append(model)
            return SimpleNamespace(text="ok")

    monkeypatch.setattr("google.genai.Client", lambda **_kwargs: SimpleNamespace(models=FakeModels()))
    result = await GeminiClient(_settings())._generate_text("probe")

    assert result == "ok"
    assert requested_models == ["gemini-configured-model"]
