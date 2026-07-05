from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import io
import json
import re
from hashlib import sha256
from html import escape
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit, urlunsplit

from PIL import Image

from backend.app.services.catalog_repository import normalize_product


CATEGORIES = ("fashion", "electronics", "home", "skincare", "fitness", "accessories")
CATEGORY_DISTRIBUTION = {
    "fashion": 9,
    "electronics": 7,
    "home": 9,
    "skincare": 8,
    "fitness": 8,
    "accessories": 9,
}
GROQ_CONFIDENCE_THRESHOLD = 0.80
GEMINI_CONFIDENCE_THRESHOLD = 0.75
COMPOSITE_CONFIDENCE_THRESHOLD = 0.82
IMAGE_HASH_DISTANCE_THRESHOLD = 10
STOPWORDS = {
    "the",
    "and",
    "with",
    "for",
    "this",
    "that",
    "from",
    "into",
    "hero",
    "product",
    "image",
    "photo",
    "item",
    "style",
    "look",
}
COLOR_ALIASES = {
    "off white": "white",
    "ivory": "white",
    "cream": "cream",
    "charcoal": "gray",
    "grey": "gray",
    "tan": "beige",
    "camel": "beige",
}
MATERIAL_ALIASES = {
    "vegan leather": "faux leather",
    "pu leather": "faux leather",
    "microfiber leather": "faux leather",
    "stainless steel": "steel",
}
STYLE_ALIASES = {
    "scandinavian": "scandi",
    "minimalist": "minimal",
    "athleisure": "sport",
}
TAG_ALIASES = {
    "moisturiser": "moisturizer",
    "earbuds": "earbuds",
}
TOKEN_RE = re.compile(r"[a-z0-9]+")


class CatalogSeedError(RuntimeError):
    pass


@dataclass(frozen=True)
class SlotManifest:
    id: str
    category: str
    price: float
    sale_price: float | None
    rating: float
    review_count: int
    inventory: int
    is_new: bool
    is_sale: bool
    created_at: str


@dataclass(frozen=True)
class CatalogBrief:
    slot_id: str
    category: str
    concept: str
    search_phrases: list[str]
    expected_attributes: list[str]
    banned_overlap_terms: list[str]


@dataclass(frozen=True)
class UnsplashCandidate:
    photo_id: str
    image_url: str
    query: str
    slug: str
    alt_description: str | None
    description: str | None
    color: str | None
    width: int
    height: int
    likes: int
    photographer_name: str | None
    tags: list[str]
    download_location: str | None
    raw: dict[str, Any]


@dataclass(frozen=True)
class CandidateEvaluation:
    slot_id: str
    brief: CatalogBrief
    candidate: UnsplashCandidate
    groq_review: dict[str, Any]
    gemini_review: dict[str, Any]
    composite_score: float
    image_hash: str
    photo_context: dict[str, Any]
    image_bytes: bytes
    mime_type: str
    byte_hash: str = ""


def load_slot_manifest(products: list[dict[str, Any]]) -> list[SlotManifest]:
    manifest = [
        SlotManifest(
            id=str(product["id"]),
            category=str(product["category"]),
            price=float(product["price"]),
            sale_price=float(product["salePrice"]) if product.get("salePrice") is not None else None,
            rating=float(product["rating"]),
            review_count=int(product["reviewCount"]),
            inventory=int(product["inventory"]),
            is_new=bool(product["isNew"]),
            is_sale=bool(product["isSale"]),
            created_at=str(product["createdAt"]),
        )
        for product in products
    ]
    validate_slot_manifest(manifest)
    return manifest


def load_blueprints(path: Path) -> tuple[list[SlotManifest], dict[str, CatalogBrief], list[dict[str, Any]]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise CatalogSeedError("Catalog blueprint must be a JSON array")
    manifest = load_slot_manifest(payload)
    briefs: dict[str, CatalogBrief] = {}
    concepts: set[str] = set()
    for item in payload:
        slot_id = str(item["id"])
        concept = normalize_sentence(item.get("concept") or "").lower()
        queries = normalize_terms(item.get("queries", []), field="tags")
        expected = normalize_terms(item.get("expectedAttributes", []), field="tags")
        forbidden = normalize_terms(item.get("forbiddenOverlaps", []), field="tags")
        if not concept or concept in concepts or not queries or not expected:
            raise CatalogSeedError(f"Invalid or duplicate blueprint concept for {slot_id}")
        concepts.add(concept)
        briefs[slot_id] = CatalogBrief(slot_id, str(item["category"]), concept, queries, expected, forbidden)
    return manifest, briefs, payload


def validate_slot_manifest(manifest: list[SlotManifest]) -> None:
    if len(manifest) != 50:
        raise CatalogSeedError(f"Expected 50 product slots, found {len(manifest)}")
    ids = [slot.id for slot in manifest]
    expected_ids = [f"p{index:03d}" for index in range(1, 51)]
    if ids != expected_ids:
        raise CatalogSeedError("Slot manifest IDs must remain p001 through p050 in order")
    counts: dict[str, int] = {}
    for slot in manifest:
        counts[slot.category] = counts.get(slot.category, 0) + 1
    if counts != CATEGORY_DISTRIBUTION:
        raise CatalogSeedError(f"Category distribution mismatch: {counts}")


def brief_from_payload(payload: dict[str, Any], *, category: str, slot_id: str) -> CatalogBrief:
    search_phrases = normalize_terms(payload.get("searchPhrases", []), field="tags")
    expected_attributes = normalize_terms(payload.get("expectedAttributes", []), field="tags")
    banned_overlap_terms = normalize_terms(payload.get("bannedOverlapTerms", []), field="tags")
    concept = normalize_sentence(payload.get("concept") or "")
    if not concept or not search_phrases or not expected_attributes:
        raise CatalogSeedError(f"Invalid brief returned for {slot_id}")
    return CatalogBrief(
        slot_id=slot_id,
        category=category,
        concept=concept,
        search_phrases=search_phrases,
        expected_attributes=expected_attributes,
        banned_overlap_terms=banned_overlap_terms,
    )


def build_unsplash_queries(brief: CatalogBrief, *, refined: bool = False) -> list[str]:
    base_queries = [
        f"{brief.category} {brief.concept}",
        *brief.search_phrases,
    ]
    if refined:
        refined_phrases = [
            f"{brief.category} {' '.join(brief.expected_attributes[:3])} {brief.concept}",
            f"{brief.concept} {' '.join(brief.expected_attributes[:2])}",
        ]
        base_queries.extend(refined_phrases)

    result: list[str] = []
    seen: set[str] = set()
    for query in base_queries:
        cleaned = " ".join(TOKEN_RE.findall(str(query).lower())).strip()
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        result.append(cleaned)
    return result[:6]


def parse_unsplash_candidate(payload: dict[str, Any], query: str) -> UnsplashCandidate:
    urls = payload.get("urls") or {}
    raw_url = urls.get("regular") or urls.get("small") or urls.get("full")
    if not raw_url:
        raise CatalogSeedError("Unsplash candidate is missing an image URL")
    user = payload.get("user") or {}
    tags = []
    for item in payload.get("tags") or []:
        if isinstance(item, dict):
            value = item.get("title") or item.get("name")
        else:
            value = item
        if value:
            tags.append(str(value))
    return UnsplashCandidate(
        photo_id=str(payload.get("id") or payload.get("slug") or raw_url),
        image_url=ensure_transformed_url(str(raw_url)),
        query=query,
        slug=str(payload.get("slug") or payload.get("id") or query.replace(" ", "-")),
        alt_description=payload.get("alt_description"),
        description=payload.get("description"),
        color=payload.get("color"),
        width=int(payload.get("width") or 0),
        height=int(payload.get("height") or 0),
        likes=int(payload.get("likes") or 0),
        photographer_name=user.get("name") or user.get("username"),
        tags=normalize_terms(tags, field="tags"),
        download_location=(payload.get("links") or {}).get("download_location"),
        raw=payload,
    )


def build_photo_context(candidate: UnsplashCandidate) -> dict[str, Any]:
    return {
        "photoId": candidate.photo_id,
        "slug": candidate.slug,
        "query": candidate.query,
        "altDescription": candidate.alt_description,
        "description": candidate.description,
        "color": candidate.color,
        "width": candidate.width,
        "height": candidate.height,
        "likes": candidate.likes,
        "photographerName": candidate.photographer_name,
        "tags": candidate.tags,
        "imageUrl": candidate.image_url,
    }


def score_candidate(groq_review: dict[str, Any], gemini_review: dict[str, Any]) -> float:
    groq_conf = float(groq_review.get("confidence") or 0.0)
    gemini_conf = float(gemini_review.get("confidence") or 0.0)
    return round((groq_conf * 0.55) + (gemini_conf * 0.45), 4)


def evaluate_image_hash(image_bytes: bytes) -> str:
    with Image.open(io.BytesIO(image_bytes)) as image:
        grayscale = image.convert("L").resize((9, 8), Image.Resampling.LANCZOS)
        pixels = list(grayscale.getdata())
    bits: list[str] = []
    for row in range(8):
        row_start = row * 9
        for col in range(8):
            left = pixels[row_start + col]
            right = pixels[row_start + col + 1]
            bits.append("1" if left > right else "0")
    return "".join(bits)


def image_sha256(image_bytes: bytes) -> str:
    return sha256(image_bytes).hexdigest()


def canonical_image_url(image_url: str) -> str:
    parts = urlsplit(image_url)
    return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path.rstrip("/"), "", ""))


def hamming_distance(left: str, right: str) -> int:
    if len(left) != len(right):
        raise ValueError("Image hashes must have the same length")
    return sum(1 for a, b in zip(left, right) if a != b)


def is_candidate_viable(evaluation: CandidateEvaluation) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    groq_category = str(evaluation.groq_review.get("category") or "")
    gemini_category = str(evaluation.gemini_review.get("category") or "")
    if groq_category != evaluation.brief.category or gemini_category != evaluation.brief.category:
        reasons.append("category_mismatch")
    if groq_category != gemini_category:
        reasons.append("provider_disagreement")
    if float(evaluation.groq_review.get("confidence") or 0.0) < GROQ_CONFIDENCE_THRESHOLD:
        reasons.append("groq_confidence_low")
    if float(evaluation.gemini_review.get("confidence") or 0.0) < GEMINI_CONFIDENCE_THRESHOLD:
        reasons.append("gemini_confidence_low")
    if evaluation.composite_score < COMPOSITE_CONFIDENCE_THRESHOLD:
        reasons.append("composite_confidence_low")
    if evaluation.groq_review.get("rejectionReasons"):
        reasons.append("groq_rejected")
    gemini_rejections = evaluation.gemini_review.get("rejectionReasons") or []
    if any(not is_benign_lifestyle_rejection(reason) for reason in gemini_rejections):
        reasons.append("gemini_rejected")
    if evaluation.groq_review.get("heroImageSuitable") is not True:
        reasons.append("groq_hero_unsuitable")
    if evaluation.gemini_review.get("heroImageSuitable") is not True and any(
        not is_benign_lifestyle_rejection(reason) for reason in gemini_rejections
    ):
        reasons.append("gemini_hero_unsuitable")
    if evaluation.gemini_review.get("titleSupported") is not True and not normalize_sentence(
        evaluation.gemini_review.get("correctedName") or ""
    ):
        reasons.append("title_unsupported")
    if evaluation.gemini_review.get("descriptionSupported") is not True and not normalize_sentence(
        evaluation.gemini_review.get("correctedDescription") or ""
    ):
        reasons.append("description_unsupported")
    groq_object = normalize_term(evaluation.groq_review.get("objectType") or "")
    gemini_object = normalize_term(evaluation.gemini_review.get("objectType") or "")
    if not groq_object or not gemini_object or not object_types_agree(groq_object, gemini_object):
        reasons.append("object_type_disagreement")
    if not normalize_sentence(evaluation.groq_review.get("name") or ""):
        reasons.append("missing_name")
    if not normalize_sentence(evaluation.groq_review.get("description") or ""):
        reasons.append("missing_description")
    if not normalize_terms(evaluation.groq_review.get("colors", []), field="colors"):
        reasons.append("missing_colors")
    if not normalize_terms(evaluation.gemini_review.get("colors", []), field="colors"):
        reasons.append("missing_verified_colors")
    return (not reasons, reasons)


def is_benign_lifestyle_rejection(reason: Any) -> bool:
    text = normalize_sentence(reason).lower()
    return any(
        phrase in text
        for phrase in (
            "lifestyle", "human element", "model rather than", "not a product-only",
            "not a clean ecommerce", "composition is a scene", "hand held",
        )
    )


def object_types_agree(left: str, right: str) -> bool:
    left_tokens = set(TOKEN_RE.findall(left))
    right_tokens = set(TOKEN_RE.findall(right))
    generic = {"product", "item", "object"}
    left_tokens -= generic
    right_tokens -= generic
    if not left_tokens:
        return bool(right_tokens)
    if not right_tokens:
        return bool(left_tokens)
    return bool(left_tokens and right_tokens and (left_tokens <= right_tokens or right_tokens <= left_tokens or left_tokens & right_tokens))


def consensus_terms(left: list[Any], right: list[Any], *, field: str) -> list[str]:
    left_values = normalize_terms(left, field=field)
    right_values = normalize_terms(right, field=field)
    right_tokens = {token for value in right_values for token in TOKEN_RE.findall(value)}
    return [value for value in left_values if set(TOKEN_RE.findall(value)) & right_tokens]


def select_assignments(
    *,
    manifest: list[SlotManifest],
    briefs: dict[str, CatalogBrief],
    evaluations_by_slot: dict[str, list[CandidateEvaluation]],
) -> tuple[dict[str, CandidateEvaluation], dict[str, Any]]:
    diagnostics: dict[str, Any] = {"rejections": {}, "similarity": {}}
    viable_by_slot: dict[str, list[CandidateEvaluation]] = {}
    for slot in manifest:
        viable_by_slot[slot.id] = []
        for item in evaluations_by_slot.get(slot.id, []):
            viable, reasons = is_candidate_viable(item)
            if viable:
                viable_by_slot[slot.id].append(item)
            else:
                diagnostics["rejections"].setdefault(slot.id, []).append({"photoId": item.candidate.photo_id, "reasons": reasons})
        viable_by_slot[slot.id].sort(key=lambda item: (item.composite_score, item.candidate.likes), reverse=True)

    slot_order = sorted(manifest, key=lambda slot: (len(viable_by_slot[slot.id]), slot.id))
    best: dict[str, CandidateEvaluation] = {}
    best_score = -1.0
    nodes = 0

    def search(index: int, chosen: dict[str, CandidateEvaluation], score: float) -> None:
        nonlocal best, best_score, nodes
        nodes += 1
        if nodes > 100_000:
            return
        if index == len(slot_order):
            if score > best_score:
                best, best_score = dict(chosen), score
            return
        upper = score + sum((viable_by_slot[item.id][0].composite_score if viable_by_slot[item.id] else 0.0) for item in slot_order[index:])
        if upper <= best_score:
            return
        slot = slot_order[index]
        for evaluation in viable_by_slot[slot.id]:
            conflict = assignment_conflict(evaluation, chosen)
            if conflict:
                diagnostics["rejections"].setdefault(slot.id, []).append({"photoId": evaluation.candidate.photo_id, "reasons": [conflict]})
                continue
            chosen[slot.id] = evaluation
            search(index + 1, chosen, score + evaluation.composite_score)
            chosen.pop(slot.id)

    search(0, {}, 0.0)
    for slot_id, evaluation in best.items():
        nearest_slot_id, nearest_distance = nearest_image(evaluation, {key: value for key, value in best.items() if key != slot_id})
        diagnostics["similarity"][slot_id] = {"nearestSlotId": nearest_slot_id, "nearestDistance": nearest_distance}
    diagnostics["searchNodes"] = nodes
    return best, diagnostics


def assignment_conflict(evaluation: CandidateEvaluation, chosen: dict[str, CandidateEvaluation]) -> str | None:
    title = normalize_sentence(evaluation.groq_review.get("name") or "").lower()
    canonical_url = canonical_image_url(evaluation.candidate.image_url)
    byte_hash = evaluation.byte_hash or image_sha256(evaluation.image_bytes)
    for other in chosen.values():
        if evaluation.candidate.photo_id == other.candidate.photo_id:
            return "duplicate_photo_id"
        if canonical_url == canonical_image_url(other.candidate.image_url):
            return "duplicate_image_url"
        if byte_hash == (other.byte_hash or image_sha256(other.image_bytes)):
            return "duplicate_image_bytes"
        if title == normalize_sentence(other.groq_review.get("name") or "").lower():
            return "duplicate_title"
        if hamming_distance(evaluation.image_hash, other.image_hash) <= IMAGE_HASH_DISTANCE_THRESHOLD:
            return "near_duplicate_image"
    return None


def nearest_image(evaluation: CandidateEvaluation, chosen: dict[str, CandidateEvaluation]) -> tuple[str | None, int | None]:
    nearest_slot_id = None
    nearest_distance = None
    for slot_id, other in chosen.items():
        distance = hamming_distance(evaluation.image_hash, other.image_hash)
        if nearest_distance is None or distance < nearest_distance:
            nearest_slot_id, nearest_distance = slot_id, distance
    return nearest_slot_id, nearest_distance


def compose_staged_product(slot: SlotManifest, evaluation: CandidateEvaluation) -> dict[str, Any]:
    colors = consensus_terms(evaluation.groq_review.get("colors", []), evaluation.gemini_review.get("colors", []), field="colors")
    if not colors:
        colors = normalize_terms(evaluation.gemini_review.get("colors", []), field="colors")
    materials = consensus_terms(evaluation.groq_review.get("materials", []), evaluation.gemini_review.get("materials", []), field="materials")
    style = consensus_terms(evaluation.groq_review.get("style", []), evaluation.gemini_review.get("style", []), field="style")
    object_type = normalize_term(evaluation.groq_review.get("objectType") or "")
    tags = normalize_terms([slot.category, object_type, *colors, *materials, *style], field="tags")
    name = evaluation.groq_review["name"]
    description = evaluation.groq_review["description"]
    if evaluation.gemini_review.get("titleSupported") is not True:
        name = evaluation.gemini_review.get("correctedName") or name
    if evaluation.gemini_review.get("descriptionSupported") is not True:
        description = evaluation.gemini_review.get("correctedDescription") or description
    product = {
        "id": slot.id,
        "name": normalize_sentence(name),
        "description": normalize_sentence(description),
        "price": slot.price,
        "salePrice": slot.sale_price,
        "category": slot.category,
        "colors": colors,
        "materials": materials,
        "style": style,
        "tags": tags,
        "imageUrls": [evaluation.candidate.image_url],
        "rating": slot.rating,
        "reviewCount": slot.review_count,
        "inventory": slot.inventory,
        "isNew": slot.is_new,
        "isSale": slot.is_sale,
        "createdAt": slot.created_at,
    }
    normalized = normalize_product(product)
    normalized["imageUrls"] = product["imageUrls"]
    return normalized


def build_audit_entry(
    slot: SlotManifest,
    evaluation: CandidateEvaluation,
    *,
    diagnostics: dict[str, Any],
) -> dict[str, Any]:
    product = compose_staged_product(slot, evaluation)
    return {
        "slotId": slot.id,
        "category": slot.category,
        "concept": evaluation.brief.concept,
        "finalTitle": product["name"],
        "finalCategory": slot.category,
        "unsplash": {
            "photoId": evaluation.candidate.photo_id,
            "query": evaluation.candidate.query,
            "imageUrl": evaluation.candidate.image_url,
            "photographerName": evaluation.candidate.photographer_name,
        },
        "groq": {
            "confidence": float(evaluation.groq_review["confidence"]),
            "category": evaluation.groq_review["category"],
            "objectType": evaluation.groq_review.get("objectType"),
            "rejectionReasons": evaluation.groq_review.get("rejectionReasons", []),
        },
        "gemini": {
            "confidence": float(evaluation.gemini_review["confidence"]),
            "category": evaluation.gemini_review["category"],
            "objectType": evaluation.gemini_review.get("objectType"),
            "rejectionReasons": evaluation.gemini_review.get("rejectionReasons", []),
        },
        "normalizedAttributes": {
            "colors": product["colors"],
            "materials": product["materials"],
            "style": product["style"],
            "tags": product["tags"],
        },
        "uniqueness": diagnostics.get("similarity", {}).get(slot.id, {"nearestSlotId": None, "nearestDistance": None}),
        "candidateRejections": diagnostics.get("rejections", {}).get(slot.id, []),
        "compositeScore": evaluation.composite_score,
    }


def validate_staged_catalog(
    *,
    manifest: list[SlotManifest],
    products: list[dict[str, Any]],
    audits: list[dict[str, Any]],
) -> None:
    if len(products) != len(manifest):
        raise CatalogSeedError(f"Expected {len(manifest)} staged products, found {len(products)}")
    ids = [product["id"] for product in products]
    expected_ids = [slot.id for slot in manifest]
    if ids != expected_ids:
        raise CatalogSeedError("Staged product IDs do not match the slot manifest")

    category_counts: dict[str, int] = {}
    photo_ids: set[str] = set()
    image_urls: set[str] = set()
    byte_hashes: set[str] = set()
    titles: set[str] = set()
    image_hash_by_slot: dict[str, str] = {}
    audit_by_slot = {audit["slotId"]: audit for audit in audits}
    if len(audit_by_slot) != len(products):
        raise CatalogSeedError("Audit entries must exist for every staged product")

    from backend.app.schemas.generated import Product

    for product in products:
        Product.model_validate(product)
        category = product["category"]
        category_counts[category] = category_counts.get(category, 0) + 1
        required = {
            "name": normalize_sentence(product.get("name") or ""),
            "description": normalize_sentence(product.get("description") or ""),
            "category": category,
            "colors": product.get("colors") or [],
            "tags": product.get("tags") or [],
            "imageUrl": (product.get("imageUrls") or [None])[0],
        }
        if not all(required.values()):
            raise CatalogSeedError(f"Staged product {product['id']} is missing required catalog fields")

        title = normalize_sentence(product["name"]).lower()
        if title in titles:
            raise CatalogSeedError(f"Duplicate product title detected: {product['name']}")
        titles.add(title)

        audit = audit_by_slot[product["id"]]
        photo_id = audit["unsplash"]["photoId"]
        image_url = canonical_image_url(audit["unsplash"]["imageUrl"])
        if photo_id in photo_ids:
            raise CatalogSeedError(f"Duplicate Unsplash photo ID detected: {photo_id}")
        if image_url in image_urls:
            raise CatalogSeedError(f"Duplicate image URL detected: {image_url}")
        photo_ids.add(photo_id)
        image_urls.add(image_url)
        byte_hash = audit.get("byteHash")
        if not byte_hash or byte_hash in byte_hashes:
            raise CatalogSeedError(f"Missing or duplicate image byte hash for {product['id']}")
        byte_hashes.add(byte_hash)

        if audit["groq"]["category"] != category or audit["gemini"]["category"] != category:
            raise CatalogSeedError(f"Provider category mismatch for {product['id']}")
        if audit["groq"]["confidence"] < GROQ_CONFIDENCE_THRESHOLD:
            raise CatalogSeedError(f"Groq confidence below threshold for {product['id']}")
        if audit["gemini"]["confidence"] < GEMINI_CONFIDENCE_THRESHOLD:
            raise CatalogSeedError(f"Gemini confidence below threshold for {product['id']}")
        if audit["compositeScore"] < COMPOSITE_CONFIDENCE_THRESHOLD:
            raise CatalogSeedError(f"Composite score below threshold for {product['id']}")
        if not object_types_agree(
            normalize_term(audit["groq"].get("objectType") or ""),
            normalize_term(audit["gemini"].get("objectType") or ""),
        ):
            raise CatalogSeedError(f"Provider object type mismatch for {product['id']}")

        if not search_tokens_are_meaningful(product):
            raise CatalogSeedError(f"Search tokens are not meaningful for {product['id']}")
        image_hash_by_slot[product["id"]] = audit["imageHash"]

    if category_counts != CATEGORY_DISTRIBUTION:
        raise CatalogSeedError(f"Staged category counts do not match the manifest: {category_counts}")

    slot_ids = [slot.id for slot in manifest]
    for index, slot_id in enumerate(slot_ids):
        for other_slot_id in slot_ids[index + 1 :]:
            distance = hamming_distance(image_hash_by_slot[slot_id], image_hash_by_slot[other_slot_id])
            if distance <= IMAGE_HASH_DISTANCE_THRESHOLD:
                raise CatalogSeedError(
                    f"Near-duplicate image pair detected between {slot_id} and {other_slot_id} (distance={distance})"
                )


def render_contact_sheet(audits: list[dict[str, Any]]) -> str:
    cards = []
    for audit in audits:
        cards.append(
            '<article class="card">'
            f'<img src="{escape(audit["unsplash"]["imageUrl"])}" alt="{escape(audit["finalTitle"])}">'
            f'<div><strong>{escape(audit["slotId"])} · {escape(audit["finalTitle"])}</strong>'
            f'<p>{escape(audit["finalCategory"])} · Groq {audit["groq"]["confidence"]:.2f} · Gemini {audit["gemini"]["confidence"]:.2f}</p>'
            f'<small>{escape(audit["unsplash"]["query"])}</small></div></article>'
        )
    return """<!doctype html><html><head><meta charset="utf-8"><title>Catalog Review</title><style>
body{font-family:Georgia,serif;background:#f4efe5;color:#20231f;margin:24px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:18px}.card{background:#fff;border:1px solid #d8d0c2;border-radius:14px;overflow:hidden;box-shadow:0 8px 24px #403b3014}.card img{width:100%;aspect-ratio:4/5;object-fit:cover}.card div{padding:12px}.card p{margin:7px 0;font:13px sans-serif}.card small{color:#676255}</style></head><body><h1>Catalog Review</h1><div class="grid">""" + "".join(cards) + "</div></body></html>"


def render_audit_markdown(audits: list[dict[str, Any]]) -> str:
    lines = [
        "# Catalog Audit",
        "",
        f"Generated: {datetime.now(UTC).isoformat().replace('+00:00', 'Z')}",
        "",
        "| Slot | Category | Title | Photo ID | Groq | Gemini | Composite | Similarity |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for audit in audits:
        similarity = audit["uniqueness"]
        distance = similarity.get("nearestDistance")
        similarity_text = "none" if distance is None else f"{similarity.get('nearestSlotId')} ({distance})"
        lines.append(
            f"| {audit['slotId']} | {audit['finalCategory']} | {audit['finalTitle']} | "
            f"{audit['unsplash']['photoId']} | {audit['groq']['confidence']:.2f} | "
            f"{audit['gemini']['confidence']:.2f} | {audit['compositeScore']:.2f} | {similarity_text} |"
        )
    lines.extend(["", "## Notes", ""])
    for audit in audits:
        attrs = audit["normalizedAttributes"]
        lines.append(
            f"- `{audit['slotId']}` `{audit['finalTitle']}`: "
            f"query=`{audit['unsplash']['query']}`, "
            f"colors={json.dumps(attrs['colors'])}, "
            f"materials={json.dumps(attrs['materials'])}, "
            f"style={json.dumps(attrs['style'])}, "
            f"tags={json.dumps(attrs['tags'])}"
        )
    return "\n".join(lines) + "\n"


def normalize_terms(values: list[Any], *, field: str) -> list[str]:
    aliases = {
        "colors": COLOR_ALIASES,
        "materials": MATERIAL_ALIASES,
        "style": STYLE_ALIASES,
        "tags": TAG_ALIASES,
    }.get(field, {})
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        text = normalize_term(value)
        if not text:
            continue
        text = aliases.get(text, text)
        if text in seen:
            continue
        seen.add(text)
        result.append(text)
    return result


def normalize_term(value: Any) -> str:
    text = " ".join(TOKEN_RE.findall(str(value).lower()))
    if not text or text in STOPWORDS:
        return ""
    return text.strip()


def normalize_sentence(value: Any) -> str:
    text = re.sub(r"\s+", " ", str(value).strip())
    return text


def ensure_transformed_url(image_url: str) -> str:
    if "auto=format" in image_url and "fit=crop" in image_url:
        return image_url
    separator = "&" if "?" in image_url else "?"
    return f"{image_url}{separator}auto=format&fit=crop&w=1400&q=80"


def search_tokens_are_meaningful(product: dict[str, Any]) -> bool:
    tokens = {token.lower() for token in product.get("searchTokens", [])}
    meaningful = {
        *TOKEN_RE.findall(str(product.get("name", "")).lower()),
        *TOKEN_RE.findall(str(product.get("category", "")).lower()),
    }
    for tag in product.get("tags", []):
        meaningful.update(TOKEN_RE.findall(str(tag).lower()))
    meaningful = {token for token in meaningful if token and token not in STOPWORDS}
    return bool(meaningful and meaningful.intersection(tokens))
