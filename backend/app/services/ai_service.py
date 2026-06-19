from __future__ import annotations

import asyncio
import hashlib
import math
import re
from collections import defaultdict
from copy import deepcopy
from datetime import UTC, datetime, timedelta

from backend.app.core.gemini_client import GeminiClient
from backend.app.services.catalog_repository import CatalogRepository
from backend.app.services.errors import ServiceError
from backend.app.services.event_repository import EventRepository


CATEGORIES = ("fashion", "electronics", "home", "skincare", "fitness", "accessories")
EVENT_WEIGHTS = {
    "purchase": 10.0,
    "add_to_cart": 8.0,
    "wishlist": 6.0,
    "long_dwell": 5.0,
    "product_view": 4.0,
    "visual_search_match_tap": 4.0,
    "text_search": 3.0,
    "category_tap": 2.0,
    "quick_bounce": -1.0,
}
LABEL_CATEGORY = {
    "shoe": "fitness",
    "sneaker": "fitness",
    "trainer": "fitness",
    "yoga": "fitness",
    "shirt": "fashion",
    "dress": "fashion",
    "jacket": "fashion",
    "clothing": "fashion",
    "phone": "electronics",
    "earbuds": "electronics",
    "computer": "electronics",
    "lamp": "home",
    "furniture": "home",
    "decor": "home",
    "cream": "skincare",
    "cosmetic": "skincare",
    "skincare": "skincare",
    "bag": "accessories",
    "wallet": "accessories",
    "jewelry": "accessories",
}
WORD_RE = re.compile(r"[a-z0-9]+")


def _tokens(*values) -> set[str]:
    result: set[str] = set()
    for value in values:
        if value is None:
            continue
        if isinstance(value, (list, tuple, set)):
            result.update(_tokens(*value))
        else:
            result.update(WORD_RE.findall(str(value).lower()))
    return result


def _fresh(payload: dict | None) -> bool:
    if not payload or "expiresAt" not in payload:
        return False
    expires_at = payload["expiresAt"]
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
    return expires_at > datetime.now(UTC)


class AiService:
    def __init__(
        self,
        catalog: CatalogRepository,
        events: EventRepository,
        gemini: GeminiClient,
        *,
        cache_ttl_seconds: int = 900,
    ) -> None:
        self.catalog = catalog
        self.events = events
        self.gemini = gemini
        self.cache_ttl = timedelta(seconds=cache_ttl_seconds)
        self._visual_cache: dict[str, dict] = {}

    def recommendations(self, uid: str) -> dict:
        cached = self.events.get_cache("recommendations", uid)
        if _fresh(cached):
            products_by_id = {product["id"]: product for product in self.catalog.list_products()}
            products = [products_by_id[product_id] for product_id in cached.get("forYouProductIds", []) if product_id in products_by_id]
            if products:
                return {"products": products, "fallbackUsed": cached["fallbackUsed"], "reason": cached["reason"]}

        user_events = self.events.list_events(uid)
        user = self.events.get_user(uid)
        preferences = self._preference_vector(user_events, user)
        products = [product for product in self.catalog.list_products() if product.get("inventory", 0) > 0]

        if preferences:
            scored = sorted(
                products,
                key=lambda product: (self._preference_score(product, preferences), self._popularity(product)),
                reverse=True,
            )
            result = scored[:8]
            fallback_used = False
            reason = "preference_vector"
        else:
            result = sorted(products, key=self._popularity, reverse=True)[:8]
            fallback_used = True
            reason = "trending"

        now = datetime.now(UTC)
        self.events.set_cache(
            "recommendations",
            uid,
            {
                "forYouProductIds": [product["id"] for product in result],
                "generatedAt": now,
                "expiresAt": now + self.cache_ttl,
                "fallbackUsed": fallback_used,
                "reason": reason,
            },
        )
        return {"products": result, "fallbackUsed": fallback_used, "reason": reason}

    async def visual_search(self, image: bytes, mime_type: str, ml_kit_labels: list[str]) -> dict:
        image_hash = hashlib.sha256(image).hexdigest()
        cached = self._visual_cache.get(image_hash)
        if cached and _fresh(cached):
            return deepcopy(cached["response"])

        fallback = False
        try:
            detected = await asyncio.wait_for(self.gemini.detect_attributes(image, mime_type), timeout=3.0)
            detected = self._normalize_detected(detected)
        except Exception:
            fallback = True
            detected = self._fallback_detected(ml_kit_labels)

        response = self._match_products(detected, ml_kit_labels, fallback)
        now = datetime.now(UTC)
        self._visual_cache[image_hash] = {"response": deepcopy(response), "expiresAt": now + self.cache_ttl}
        return response

    async def explain_product(self, request: dict) -> dict:
        uid = request["uid"]
        product = self.catalog.get_product(request["productId"])
        if not product:
            raise ServiceError(404, "product_not_found", "Cannot explain a product that does not exist")

        user = self.events.get_user(uid)
        preference_vector = self._preference_vector(self.events.list_events(uid), user)
        top_tags = [tag for tag, weight in sorted(preference_vector.items(), key=lambda item: item[1], reverse=True) if weight > 0][:3]
        if not top_tags:
            raise ServiceError(404, "preference_signal_missing", "No preference signal is available for this user")

        segment = top_tags[0]
        tag_hash = hashlib.sha256("|".join(top_tags).encode()).hexdigest()[:16]
        cache_key = hashlib.sha256(f"{product['id']}|{segment}|{tag_hash}".encode()).hexdigest()
        cached = self.events.get_cache("explanations", cache_key)
        if _fresh(cached):
            return {
                "explanationText": cached["explanationText"],
                "provider": cached["provider"],
                "cached": True,
            }

        provider = "gemini"
        try:
            explanation = await asyncio.wait_for(self.gemini.explain(product, top_tags), timeout=3.0)
            if not explanation:
                raise RuntimeError("Empty explanation")
        except Exception:
            provider = "template"
            attribute = self._best_attribute(product, top_tags)
            explanation = f"Because you showed interest in {top_tags[0]}, this product's {attribute} may match your style."

        now = datetime.now(UTC)
        self.events.set_cache(
            "explanations",
            cache_key,
            {
                "productId": product["id"],
                "segment": segment,
                "tagHash": tag_hash,
                "explanationText": explanation,
                "provider": provider,
                "generatedAt": now,
                "expiresAt": now + self.cache_ttl,
            },
        )
        return {"explanationText": explanation, "provider": provider, "cached": False}

    def _preference_vector(self, user_events: list[dict], user: dict | None) -> dict[str, float]:
        vector: defaultdict[str, float] = defaultdict(float)
        for preference in (user or {}).get("preferences", []) or []:
            vector[str(preference).lower()] += 2.0

        for event in user_events:
            event_type = event.get("eventType")
            weight = EVENT_WEIGHTS.get(event_type, 0.0)
            metadata = event.get("metadata") or {}
            if event_type == "product_view" and int(metadata.get("dwellMs", 0)) <= 3000:
                continue

            product = self.catalog.get_product(str(event.get("productId"))) if event.get("productId") else None
            signal_tokens = _tokens(
                event.get("category"),
                metadata.get("tags"),
                metadata.get("query"),
                product.get("category") if product else None,
                product.get("tags") if product else None,
                product.get("style") if product else None,
            )
            for token in signal_tokens:
                vector[token] += weight

        scale = max((abs(weight) for weight in vector.values()), default=0.0)
        return {tag: weight / scale for tag, weight in vector.items()} if scale else {}

    def _preference_score(self, product: dict, preferences: dict[str, float]) -> float:
        product_tokens = _tokens(
            product["category"],
            product.get("tags", []),
            product.get("style", []),
            product.get("colors", []),
            product.get("materials", []),
            product.get("searchTokens", []),
        )
        return sum(preferences.get(token, 0.0) for token in product_tokens)

    def _match_products(self, detected: dict, labels: list[str], fallback: bool) -> dict:
        query_tokens = sorted(
            _tokens(
                labels,
                detected["objectType"],
                detected["colors"],
                detected["materials"],
                detected["style"],
                detected.get("suggestedTags", []),
            )
        )
        scored = [
            (self._visual_score(product, detected, query_tokens), product)
            for product in self.catalog.list_products()
            if product.get("inventory", 0) > 0
        ]
        scored.sort(key=lambda item: (item[0], self._popularity(item[1])), reverse=True)
        selected = scored[:8]
        return {
            "products": [product for _, product in selected],
            "detectedAttributes": {
                "primaryCategory": detected["primaryCategory"],
                "objectType": detected["objectType"],
                "colors": detected["colors"],
                "materials": detected["materials"],
                "style": detected["style"],
            },
            "matchScores": [round(score, 4) for score, _ in selected],
            "fallbackMode": fallback,
            "queryTokens": query_tokens,
        }

    def _visual_score(self, product: dict, detected: dict, query_tokens: list[str]) -> float:
        product_tags = _tokens(product.get("tags", []), product.get("style", []))
        query_tag_set = _tokens(detected.get("suggestedTags", []), detected.get("style"), query_tokens)
        category = 1.0 if product["category"] == detected["primaryCategory"] else 0.0
        tag_overlap = len(product_tags & query_tag_set) / max(1, len(query_tag_set))
        colors_materials = _tokens(product.get("colors", []), product.get("materials", []))
        detected_colors_materials = _tokens(detected["colors"], detected["materials"])
        visual_overlap = len(colors_materials & detected_colors_materials) / max(1, len(detected_colors_materials))
        text_tokens = _tokens(product["name"], product.get("description"), product.get("searchTokens", []))
        object_tokens = _tokens(detected["objectType"], query_tokens)
        text_overlap = len(text_tokens & object_tokens) / max(1, len(object_tokens))
        popularity = self._popularity(product)
        embedding = self._cosine_token_similarity(text_tokens | product_tags, object_tokens | query_tag_set)
        return 0.30 * category + 0.25 * tag_overlap + 0.15 * visual_overlap + 0.10 * text_overlap + 0.10 * popularity + 0.10 * embedding

    @staticmethod
    def _popularity(product: dict) -> float:
        rating = float(product.get("rating", 0)) / 5.0
        reviews = min(1.0, math.log1p(int(product.get("reviewCount", 0))) / math.log1p(350))
        return (rating + reviews) / 2.0

    @staticmethod
    def _cosine_token_similarity(left: set[str], right: set[str]) -> float:
        if not left or not right:
            return 0.0
        return len(left & right) / math.sqrt(len(left) * len(right))

    @staticmethod
    def _normalize_detected(payload: dict) -> dict:
        expected_keys = {
            "primaryCategory",
            "objectType",
            "colors",
            "materials",
            "style",
            "suggestedTags",
            "confidence",
        }
        if set(payload) != expected_keys:
            raise ValueError("Gemini response did not contain exactly the required fields")
        category = payload.get("primaryCategory")
        if category not in CATEGORIES:
            raise ValueError("Gemini returned an invalid category")
        return {
            "primaryCategory": category,
            "objectType": payload.get("objectType"),
            "colors": [str(value).lower() for value in payload.get("colors", [])],
            "materials": [str(value).lower() for value in payload.get("materials", [])],
            "style": str(payload["style"]).lower() if payload.get("style") else None,
            "suggestedTags": [str(value).lower() for value in payload.get("suggestedTags", [])],
            "confidence": float(payload.get("confidence", 0)),
        }

    @staticmethod
    def _fallback_detected(labels: list[str]) -> dict:
        label_tokens = _tokens(labels)
        category = next((LABEL_CATEGORY[token] for token in label_tokens if token in LABEL_CATEGORY), "accessories")
        object_type = next((token for token in label_tokens if token in LABEL_CATEGORY), None)
        return {
            "primaryCategory": category,
            "objectType": object_type,
            "colors": [],
            "materials": [],
            "style": None,
            "suggestedTags": sorted(label_tokens),
            "confidence": 0.0,
        }

    @staticmethod
    def _best_attribute(product: dict, top_tags: list[str]) -> str:
        candidates = [
            *product.get("materials", []),
            *product.get("style", []),
            *product.get("colors", []),
            *product.get("tags", []),
        ]
        return next((str(value) for value in candidates if str(value).lower() not in top_tags), product["category"])
