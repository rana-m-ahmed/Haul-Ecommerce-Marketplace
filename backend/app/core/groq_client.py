from __future__ import annotations

import asyncio
import json
import random
import re
from typing import Any

import httpx

from backend.app.core.config import Settings


RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}
STRICT_SCHEMA_MODELS = {"openai/gpt-oss-20b", "openai/gpt-oss-120b"}


class GroqClient:
    def __init__(self, settings: Settings, *, client: httpx.AsyncClient | None = None) -> None:
        self.settings = settings
        self._external_client = client is not None
        self._client = client

    def is_configured(self) -> bool:
        return bool(self.settings.groq_api_key)

    async def __aenter__(self) -> "GroqClient":
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=self.settings.catalog_request_timeout_seconds)
        return self

    async def __aexit__(self, *_args: object) -> None:
        if self._client is not None and not self._external_client:
            await self._client.aclose()
            self._client = None

    async def probe(self) -> None:
        schema = {
            "type": "object",
            "required": ["ok"],
            "properties": {"ok": {"type": "boolean"}},
            "additionalProperties": False,
        }
        await self._generate_json(prompt="Return JSON with ok set to true.", schema=schema)

    async def review_catalog_candidate(
        self,
        *,
        image_url: str,
        brief: dict[str, Any],
        photo_context: dict[str, Any],
    ) -> dict[str, Any]:
        schema = {
            "type": "object",
            "required": [
                "name", "description", "category", "objectType", "colors", "materials",
                "style", "tags", "confidence", "rejectionReasons", "heroImageSuitable",
            ],
            "properties": {
                "name": {"type": "string"},
                "description": {"type": "string"},
                "category": {"type": "string", "enum": ["fashion", "electronics", "home", "skincare", "fitness", "accessories"]},
                "objectType": {"type": "string"},
                "colors": {"type": "array", "items": {"type": "string"}},
                "materials": {"type": "array", "items": {"type": "string"}},
                "style": {"type": "array", "items": {"type": "string"}},
                "tags": {"type": "array", "items": {"type": "string"}},
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                "rejectionReasons": {"type": "array", "items": {"type": "string"}},
                "heroImageSuitable": {"type": "boolean"},
            },
            "additionalProperties": False,
        }
        prompt = (
            "Act as a strict ecommerce visual merchandiser. Inspect the image, not merely its URL metadata. "
            "Accept only one clearly visible purchasable product matching the brief. Reject ambiguous subjects, "
            "wrong categories, collages, and poor hero compositions. Use factual visible attributes only. "
            "The name must be unique-sounding, 2-5 words, and the description one factual sentence. "
            "Return only the requested JSON.\n"
            f"Brief: {json.dumps(brief, sort_keys=True)}\n"
            f"Photo context: {json.dumps(photo_context, sort_keys=True)}"
        )
        try:
            return await self._generate_json(prompt=prompt, schema=schema, image_url=image_url, retries=0)
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code != 429:
                raise
            fallback_prompt = (
                prompt
                + "\nThe vision token window is rate-limited. Review conservatively using only the fixed brief "
                "and Unsplash photo context. Lower confidence or reject whenever those fields do not clearly support the product."
            )
            return await self._generate_json(prompt=fallback_prompt, schema=schema, retries=2)

    async def _generate_json(
        self,
        *,
        prompt: str,
        schema: dict[str, Any],
        image_url: str | None = None,
        retries: int = 2,
    ) -> dict[str, Any]:
        text = await self._generate(prompt=prompt, schema=schema, image_url=image_url, retries=retries)
        payload = json.loads(text)
        if not isinstance(payload, dict):
            raise RuntimeError("Groq returned a non-object JSON response")
        return payload

    async def _generate(
        self,
        *,
        prompt: str,
        schema: dict[str, Any],
        image_url: str | None = None,
        retries: int = 2,
    ) -> str:
        if not self.is_configured():
            raise RuntimeError("Groq is not configured")
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=self.settings.catalog_request_timeout_seconds)

        content: list[dict[str, Any]] = [{"type": "text", "text": prompt}]
        if image_url:
            content.append({"type": "image_url", "image_url": {"url": image_url}})
        schema_payload: dict[str, Any] = {"name": "catalog_reseed", "schema": _prepare_schema(schema)}
        if self.settings.groq_model in STRICT_SCHEMA_MODELS:
            schema_payload["strict"] = True
        request = {
            "model": self.settings.groq_model,
            "temperature": 0.1,
            "response_format": {"type": "json_schema", "json_schema": schema_payload},
            "messages": [{"role": "user", "content": content}],
        }
        response: httpx.Response | None = None
        for attempt in range(retries + 1):
            response = await self._client.post(
                f"{self.settings.groq_base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {self.settings.groq_api_key}"},
                json=request,
            )
            if response.status_code not in RETRYABLE_STATUS_CODES:
                response.raise_for_status()
                break
            if attempt == retries:
                response.raise_for_status()
            delay = min(20.0, _retry_after(response) or (2**attempt + random.random()))
            await asyncio.sleep(delay)
        assert response is not None
        body = response.json()
        choices = body.get("choices") or []
        message = (choices[0].get("message") or {}).get("content") if choices else None
        if isinstance(message, str) and message.strip():
            return message
        raise RuntimeError("Groq returned no text content")


def _prepare_schema(value: Any) -> Any:
    if isinstance(value, dict):
        prepared = {key: _prepare_schema(item) for key, item in value.items()}
        if prepared.get("type") == "object":
            prepared.setdefault("additionalProperties", False)
        return prepared
    if isinstance(value, list):
        return [_prepare_schema(item) for item in value]
    return value


def _retry_after(response: httpx.Response) -> float | None:
    value = response.headers.get("retry-after")
    if value:
        try:
            return float(value)
        except ValueError:
            pass
    match = re.search(r"try again in ([0-9.]+)s", response.text, flags=re.IGNORECASE)
    return float(match.group(1)) if match else None
