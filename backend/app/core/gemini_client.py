from __future__ import annotations

import asyncio
import json
import random
from functools import partial

from backend.app.core.config import Settings


class GeminiClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._client = None

    def is_configured(self) -> bool:
        return bool(self.settings.gemini_api_key) and not self.settings.gemini_disabled

    async def probe(self) -> None:
        result = await self._generate_text("Reply with exactly: ok")
        if "ok" not in result.lower():
            raise RuntimeError("Gemini probe returned an unexpected response")

    async def detect_attributes(self, image: bytes, mime_type: str) -> dict:
        schema = {
            "type": "object",
            "required": [
                "primaryCategory",
                "objectType",
                "colors",
                "materials",
                "style",
                "suggestedTags",
                "confidence",
            ],
            "properties": {
                "primaryCategory": {
                    "type": "string",
                    "enum": ["fashion", "electronics", "home", "skincare", "fitness", "accessories"],
                },
                "objectType": {"type": "string", "nullable": True},
                "colors": {"type": "array", "items": {"type": "string"}},
                "materials": {"type": "array", "items": {"type": "string"}},
                "style": {"type": "string", "nullable": True},
                "suggestedTags": {"type": "array", "items": {"type": "string"}},
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
            },
        }
        prompt = (
            "Identify the single purchasable product in this image. Return exactly the JSON schema supplied. "
            "Use only these primaryCategory values: fashion, electronics, home, skincare, fitness, accessories. "
            "Keep colors, materials, and suggestedTags short, lowercase, and factual. Do not add prose."
        )
        return await self._generate_json(prompt, image=image, mime_type=mime_type, schema=schema)

    async def explain(self, product: dict, preference_tags: list[str]) -> str:
        prompt = (
            "Write at most two short sentences explaining why this product may suit the user. "
            "Use only the supplied product attributes and preference tags; do not invent facts.\n"
            f"Product: {json.dumps(product, default=str)}\n"
            f"Preference tags: {json.dumps(preference_tags)}"
        )
        result = await self._generate_text(prompt)
        sentences = [part.strip() for part in result.replace("!", ".").replace("?", ".").split(".") if part.strip()]
        return ". ".join(sentences[:2]) + ("." if sentences else "")

    async def generate_catalog_metadata(
        self,
        *,
        image: bytes,
        mime_type: str,
        context: dict,
    ) -> dict:
        schema = {
            "type": "object",
            "required": ["name", "description", "category", "colors", "materials", "style", "tags"],
            "properties": {
                "name": {"type": "string"},
                "description": {"type": "string"},
                "category": {
                    "type": "string",
                    "enum": ["fashion", "electronics", "home", "skincare", "fitness", "accessories"],
                },
                "colors": {"type": "array", "items": {"type": "string"}},
                "materials": {"type": "array", "items": {"type": "string"}},
                "style": {"type": "array", "items": {"type": "string"}},
                "tags": {"type": "array", "items": {"type": "string"}},
            },
        }
        prompt = (
            "Create a plausible ecommerce catalog entry for a real Unsplash photo.\n"
            "Keep the result grounded in the image and the provided context.\n"
            "Rules:\n"
            "- Do not mention Unsplash, photography, AI, or prompts.\n"
            "- Keep the category aligned with the provided template category whenever possible.\n"
            "- Name should be 2 to 5 words in title case.\n"
            "- Description should be one concise sentence.\n"
            "- colors, materials, style, and tags should be short lowercase strings.\n"
            "- Do not include price, inventory, ratings, or other commerce metrics.\n"
            f"Context: {json.dumps(context, default=str)}"
        )
        return await self._generate_json(prompt, image=image, mime_type=mime_type, schema=schema)

    async def verify_catalog_candidate(
        self,
        *,
        image: bytes,
        mime_type: str,
        brief: dict,
        photo_context: dict,
    ) -> dict:
        schema = {
            "type": "object",
            "required": [
                "category",
                "objectType",
                "colors",
                "materials",
                "style",
                "tags",
                "confidence",
                "rejectionReasons",
                "heroImageSuitable",
                "titleSupported",
                "descriptionSupported",
                "correctedName",
                "correctedDescription",
            ],
            "properties": {
                "category": {
                    "type": "string",
                    "enum": ["fashion", "electronics", "home", "skincare", "fitness", "accessories"],
                },
                "objectType": {"type": "string"},
                "colors": {"type": "array", "items": {"type": "string"}},
                "materials": {"type": "array", "items": {"type": "string"}},
                "style": {"type": "array", "items": {"type": "string"}},
                "tags": {"type": "array", "items": {"type": "string"}},
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                "rejectionReasons": {"type": "array", "items": {"type": "string"}},
                "heroImageSuitable": {"type": "boolean"},
                "titleSupported": {"type": "boolean"},
                "descriptionSupported": {"type": "boolean"},
                "correctedName": {"type": "string"},
                "correctedDescription": {"type": "string"},
            },
        }
        prompt = (
            "Verify whether this image is a strong match for the target ecommerce brief.\n"
            "Return exactly the requested JSON.\n"
            "Rules:\n"
            "- category must reflect what is visibly shown.\n"
            "- colors, materials, style, and tags must be short lowercase strings.\n"
            "- Reject ambiguous subjects, collages, or unsupported metadata. Lifestyle images are acceptable when the requested product is the clear dominant subject.\n"
            "- titleSupported and descriptionSupported assess the Groq proposal supplied in photo context.\n"
            "- correctedName and correctedDescription must be factual replacements when support is false, otherwise repeat the proposal.\n"
            f"Brief: {json.dumps(brief, default=str)}\n"
            f"Photo context: {json.dumps(photo_context, default=str)}"
        )
        return await self._generate_json(prompt, image=image, mime_type=mime_type, schema=schema)

    async def _generate_json(self, prompt: str, *, image: bytes, mime_type: str, schema: dict) -> dict:
        from google.genai import types

        text = await self._generate(
            contents=[prompt, types.Part.from_bytes(data=image, mime_type=mime_type)],
            response_mime_type="application/json",
            response_schema=schema,
        )
        return json.loads(text)

    async def _generate_text(self, prompt: str) -> str:
        return await self._generate(contents=prompt)

    async def _generate(self, *, contents, **config_values) -> str:
        if not self.is_configured():
            raise RuntimeError("Gemini is disabled or not configured")

        from google import genai
        from google.genai import types

        if self._client is None:
            self._client = genai.Client(api_key=self.settings.gemini_api_key)
        config = types.GenerateContentConfig(**config_values)
        call = partial(
            self._client.models.generate_content,
            model=self.settings.gemini_model,
            contents=contents,
            config=config,
        )
        for attempt in range(3):
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(call),
                    timeout=self.settings.catalog_request_timeout_seconds,
                )
                if not response.text:
                    raise RuntimeError("Gemini returned no text")
                return response.text
            except asyncio.TimeoutError:
                if attempt == 2:
                    raise RuntimeError("Gemini request timed out") from None
            except Exception as exc:
                message = str(exc).lower()
                retryable = any(token in message for token in ("429", "500", "502", "503", "504", "resource_exhausted", "unavailable"))
                if not retryable or attempt == 2:
                    raise
            await asyncio.sleep(min(20.0, 2**attempt + random.random()))
        raise RuntimeError("Gemini request failed")
