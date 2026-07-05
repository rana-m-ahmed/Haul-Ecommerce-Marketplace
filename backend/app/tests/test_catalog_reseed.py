from __future__ import annotations

from hashlib import sha256
from pathlib import Path

from backend.app.services.catalog_reseed import (
    CandidateEvaluation,
    CatalogBrief,
    CatalogSeedError,
    SlotManifest,
    UnsplashCandidate,
    compose_staged_product,
    load_slot_manifest,
    load_blueprints,
    normalize_terms,
    select_assignments,
    validate_staged_catalog,
)


ROOT = Path(__file__).resolve().parents[3]
SEED_PATH = ROOT / "backend" / "seed" / "products.json"


def _hash_bits(seed: str) -> str:
    number = int(sha256(seed.encode("utf-8")).hexdigest()[:16], 16)
    return format(number, "064b")


def _slot(slot_id: str, category: str = "home") -> SlotManifest:
    return SlotManifest(
        id=slot_id,
        category=category,
        price=64.0,
        sale_price=None,
        rating=4.6,
        review_count=24,
        inventory=8,
        is_new=False,
        is_sale=False,
        created_at="2026-06-01T09:00:00Z",
    )


def _evaluation(
    *,
    slot_id: str,
    title: str,
    photo_id: str,
    image_url: str,
    image_hash: str,
    category: str = "home",
    score: float = 0.9,
) -> CandidateEvaluation:
    brief = CatalogBrief(
        slot_id=slot_id,
        category=category,
        concept=f"{category} concept {slot_id}",
        search_phrases=[f"{category} search {slot_id}"],
        expected_attributes=["matte", "minimal"],
        banned_overlap_terms=["duplicate"],
    )
    candidate = UnsplashCandidate(
        photo_id=photo_id,
        image_url=image_url,
        query=f"{category} query",
        slug=photo_id,
        alt_description=None,
        description=None,
        color="ivory",
        width=1200,
        height=1600,
        likes=42,
        photographer_name="Tester",
        tags=["hero", "modern"],
        download_location=None,
        raw={},
    )
    groq_review = {
        "name": title,
        "description": f"{title} description",
        "category": category,
        "objectType": "lamp",
        "colors": ["ivory", "charcoal"],
        "materials": ["stainless steel"],
        "style": ["minimalist"],
        "tags": ["hero", "display"],
        "confidence": 0.91,
        "rejectionReasons": [],
        "heroImageSuitable": True,
    }
    gemini_review = {
        "category": category,
        "objectType": "lamp",
        "colors": ["white"],
        "materials": ["steel"],
        "style": ["minimal"],
        "tags": ["modern"],
        "confidence": 0.88,
        "rejectionReasons": [],
        "heroImageSuitable": True,
        "titleSupported": True,
        "descriptionSupported": True,
        "correctedName": title,
        "correctedDescription": f"{title} description",
    }
    return CandidateEvaluation(
        slot_id=slot_id,
        brief=brief,
        candidate=candidate,
        groq_review=groq_review,
        gemini_review=gemini_review,
        composite_score=score,
        image_hash=image_hash,
        photo_context={"photoId": photo_id},
        image_bytes=b"test",
        mime_type="image/jpeg",
        byte_hash=sha256(f"bytes-{photo_id}".encode()).hexdigest(),
    )


def _valid_stage_fixture() -> tuple[list[SlotManifest], list[dict], list[dict]]:
    import json

    manifest = load_slot_manifest(json.loads(SEED_PATH.read_text(encoding="utf-8")))
    products: list[dict] = []
    audits: list[dict] = []
    for index, slot in enumerate(manifest, start=1):
        evaluation = _evaluation(
            slot_id=slot.id,
            title=f"{slot.category.title()} Product {index}",
            photo_id=f"photo-{index}",
            image_url=f"https://images.unsplash.com/photo-{index}",
            image_hash=_hash_bits(f"{slot.id}-{index}"),
            category=slot.category,
        )
        product = compose_staged_product(slot, evaluation)
        products.append(product)
        audits.append(
            {
                "slotId": slot.id,
                "finalTitle": product["name"],
                "finalCategory": slot.category,
                "unsplash": {
                    "photoId": evaluation.candidate.photo_id,
                    "query": evaluation.candidate.query,
                    "imageUrl": product["imageUrls"][0],
                    "photographerName": evaluation.candidate.photographer_name,
                },
                "groq": {
                    "confidence": evaluation.groq_review["confidence"],
                    "category": slot.category,
                    "objectType": "lamp",
                    "rejectionReasons": [],
                },
                "gemini": {
                    "confidence": evaluation.gemini_review["confidence"],
                    "category": slot.category,
                    "objectType": "lamp",
                    "rejectionReasons": [],
                },
                "normalizedAttributes": {
                    "colors": product["colors"],
                    "materials": product["materials"],
                    "style": product["style"],
                    "tags": product["tags"],
                },
                "uniqueness": {"nearestSlotId": None, "nearestDistance": None},
                "compositeScore": evaluation.composite_score,
                "imageHash": evaluation.image_hash,
                "byteHash": evaluation.byte_hash,
            }
        )
    return manifest, products, audits


def test_load_slot_manifest_keeps_expected_distribution() -> None:
    import json

    manifest = load_slot_manifest(json.loads(SEED_PATH.read_text(encoding="utf-8")))

    assert len(manifest) == 50
    assert manifest[0].id == "p001"
    assert manifest[-1].id == "p050"


def test_fixed_blueprint_preserves_only_immutable_slot_commerce() -> None:
    import json

    legacy = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    manifest, briefs, blueprints = load_blueprints(ROOT / "backend" / "seed" / "catalog_blueprints.json")
    commerce_fields = ("id", "category", "price", "salePrice", "rating", "reviewCount", "inventory", "isNew", "isSale", "createdAt")

    assert len(manifest) == len(briefs) == len(blueprints) == 50
    assert [{key: item[key] for key in commerce_fields} for item in blueprints] == [
        {key: item[key] for key in commerce_fields} for item in legacy
    ]
    assert len({brief.concept for brief in briefs.values()}) == 50


def test_normalize_terms_applies_aliases_and_dedupes() -> None:
    normalized = normalize_terms(["Ivory", "off white", "charcoal", "grey"], field="colors")

    assert normalized == ["white", "gray"]


def test_select_assignments_skips_duplicate_titles_and_near_duplicates() -> None:
    manifest = [_slot("p001"), _slot("p002")]
    first = _evaluation(
        slot_id="p001",
        title="Quiet Lamp",
        photo_id="photo-1",
        image_url="https://images.unsplash.com/photo-1",
        image_hash="0" * 64,
    )
    duplicate = _evaluation(
        slot_id="p002",
        title="Quiet Lamp",
        photo_id="photo-2",
        image_url="https://images.unsplash.com/photo-2",
        image_hash="0" * 64,
        score=0.95,
    )
    unique = _evaluation(
        slot_id="p002",
        title="Soft Task Light",
        photo_id="photo-3",
        image_url="https://images.unsplash.com/photo-3",
        image_hash="1" * 64,
    )

    chosen, diagnostics = select_assignments(
        manifest=manifest,
        briefs={},
        evaluations_by_slot={"p001": [first], "p002": [duplicate, unique]},
    )

    assert chosen["p001"].candidate.photo_id == "photo-1"
    assert chosen["p002"].candidate.photo_id == "photo-3"
    assert diagnostics["rejections"]["p002"]


def test_validate_staged_catalog_rejects_duplicate_unsplash_photo_ids() -> None:
    manifest, products, audits = _valid_stage_fixture()
    audits[1]["unsplash"]["photoId"] = audits[0]["unsplash"]["photoId"]

    try:
        validate_staged_catalog(manifest=manifest, products=products, audits=audits)
    except CatalogSeedError as exc:
        assert "Duplicate Unsplash photo ID" in str(exc)
    else:
        raise AssertionError("Expected duplicate photo IDs to fail validation")
