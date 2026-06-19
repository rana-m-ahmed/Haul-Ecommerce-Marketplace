from __future__ import annotations

import asyncio
import json
from functools import partial

from backend.app.core.config import Settings


class GeminiClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def is_configured(self) -> bool:
        return bool(self.settings.gemini_api_key) and not self.settings.gemini_disabled

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

        client = genai.Client(api_key=self.settings.gemini_api_key)
        config = types.GenerateContentConfig(**config_values)
        call = partial(
            client.models.generate_content,
            model="gemini-2.0-flash-lite",
            contents=contents,
            config=config,
        )
        response = await asyncio.to_thread(call)
        if not response.text:
            raise RuntimeError("Gemini returned no text")
        return response.text
