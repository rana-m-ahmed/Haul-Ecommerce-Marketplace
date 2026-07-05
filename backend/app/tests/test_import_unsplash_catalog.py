from __future__ import annotations

import json
from types import SimpleNamespace
import asyncio
from hashlib import sha256
from io import BytesIO
import random

import httpx
from PIL import Image

import pytest

from backend.app.services.catalog_reseed import CatalogSeedError
from backend.app.services.catalog_run_store import CatalogRunStore
from backend.scripts import import_unsplash_catalog as importer


def _settings(tmp_path):
    return SimpleNamespace(
        catalog_runs_path=str(tmp_path / "runs"),
        catalog_blueprint_path="backend/seed/catalog_blueprints.json",
        groq_model="groq-test",
        gemini_model="gemini-test",
        catalog_groq_budget=2,
        catalog_gemini_budget=1,
    )


def test_checkpoint_store_persists_candidates_and_request_counts(tmp_path) -> None:
    path = tmp_path / "state.sqlite3"
    store = CatalogRunStore(path)
    store.set_meta("run_id", "run-1")
    store.increment("groq_requests")
    store.set_slot("p001", "evaluated")
    store.save_candidate("p001", "photo-1", {"score": 0.91})
    store.close()

    resumed = CatalogRunStore(path)
    assert resumed.summary()["requests"]["groq"] == 1
    assert resumed.summary()["slots"] == {"evaluated": 1}
    assert resumed.candidates("p001") == [{"score": 0.91}]
    resumed.close()


def test_stage_runtime_enforces_provider_budget(tmp_path) -> None:
    store = CatalogRunStore(tmp_path / "state.sqlite3")
    runtime = importer.StageRuntime(_settings(tmp_path), store)

    runtime.reserve("groq", 1)
    store.set_meta("groq_requests", 1)
    with pytest.raises(CatalogSeedError, match="budget exceeded"):
        runtime.reserve("groq", 1)
    store.close()


@pytest.mark.asyncio
async def test_unsplash_search_response_is_checkpointed_and_reused(tmp_path) -> None:
    settings = _settings(tmp_path)
    settings.unsplash_access_key = "test"
    settings.unsplash_api_base_url = "https://unsplash.test"
    settings.catalog_request_timeout_seconds = 1.0
    store = CatalogRunStore(tmp_path / "state.sqlite3")
    runtime = importer.StageRuntime(settings, store)
    calls = 0

    def handler(request):
        nonlocal calls
        calls += 1
        return httpx.Response(
            200,
            request=request,
            headers={"x-ratelimit-remaining": "48", "x-ratelimit-reset": "123"},
            json={"results": [{"id": "photo-1"}]},
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        first = await importer.fetch_unsplash(runtime, client, "fixed query")
        second = await importer.fetch_unsplash(runtime, client, "fixed query")

    assert first == second == [{"id": "photo-1"}]
    assert calls == 1
    assert store.summary()["unsplashQuota"] == {"remaining": "48", "reset": "123"}
    store.close()


def test_artifact_checksum_is_stable_and_order_sensitive() -> None:
    first = [{"id": "p001", "name": "Lamp"}, {"id": "p002", "name": "Chair"}]
    same_keys_different_order = [{"name": "Lamp", "id": "p001"}, {"name": "Chair", "id": "p002"}]

    assert importer.artifact_checksum(first) == importer.artifact_checksum(same_keys_different_order)
    assert importer.artifact_checksum(first) != importer.artifact_checksum(list(reversed(first)))


def test_validate_run_rejects_tampered_checksum(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path)
    directory = tmp_path / "runs" / "run-1"
    directory.mkdir(parents=True)
    (directory / "products.staged.json").write_text("[]", encoding="utf-8")
    (directory / "products.audit.json").write_text("[]", encoding="utf-8")
    store = CatalogRunStore(directory / "state.sqlite3")
    store.set_meta("status", "staged")
    store.set_meta("checksum", "not-the-checksum")
    store.close()
    monkeypatch.setattr(importer, "load_blueprints", lambda _path: ([], {}, []))

    with pytest.raises(CatalogSeedError, match="checksum"):
        importer.validate_run(settings, "run-1")


def test_publish_rejects_unapproved_checksum_before_firestore(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path)
    monkeypatch.setattr(importer, "validate_run", lambda _settings, _run_id: "approved")
    monkeypatch.setattr(importer, "firestore_client", lambda _settings: pytest.fail("Firestore must not be called"))

    with pytest.raises(CatalogSeedError, match="Approved checksum"):
        importer.publish_run(settings, "run-1", "wrong")


def test_blueprint_fingerprint_changes_with_model(tmp_path) -> None:
    blueprint = tmp_path / "blueprints.json"
    blueprint.write_text(json.dumps([{"id": "p001"}]), encoding="utf-8")
    settings = _settings(tmp_path)
    first = importer.run_fingerprint(blueprint, settings)
    settings.gemini_model = "gemini-other"

    assert importer.run_fingerprint(blueprint, settings) != first


@pytest.mark.asyncio
async def test_stage_deadline_exits_with_resumable_checkpoint(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path)
    settings.catalog_deadline_minutes = 0.0001
    settings.catalog_request_timeout_seconds = 1.0
    settings.unsplash_access_key = "test"
    blueprint = tmp_path / "blueprints.json"
    blueprint.write_text("[]", encoding="utf-8")
    settings.catalog_blueprint_path = str(blueprint)
    slot = SimpleNamespace(id="p001")
    brief = SimpleNamespace(slot_id="p001")
    monkeypatch.setattr(importer, "load_blueprints", lambda _path: ([slot], {"p001": brief}, []))

    async def never_finishes(*_args, **_kwargs):
        await asyncio.sleep(1)

    monkeypatch.setattr(importer, "evaluate_slot", never_finishes)
    with pytest.raises(CatalogSeedError, match="timed out"):
        await importer.build_stage(settings, "deadline-run")

    store = CatalogRunStore(tmp_path / "runs" / "deadline-run" / "state.sqlite3")
    assert store.get_meta("status") == "timed_out"
    store.close()


@pytest.mark.asyncio
async def test_fully_mocked_stage_builds_fifty_product_review_artifacts(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path)
    settings.catalog_blueprint_path = "backend/seed/catalog_blueprints.json"
    settings.catalog_deadline_minutes = 1
    settings.catalog_request_timeout_seconds = 1.0
    settings.catalog_groq_budget = 250
    settings.catalog_gemini_budget = 120
    settings.unsplash_access_key = "test-unsplash"
    settings.unsplash_api_base_url = "https://unsplash.test"

    search_calls: list[str] = []

    async def fake_search(_runtime, _client, query, **_kwargs):
        search_calls.append(query)
        photo_id = sha256(query.encode()).hexdigest()[:16]
        return [{
            "id": photo_id,
            "slug": photo_id,
            "width": 1200,
            "height": 1600,
            "likes": 50,
            "alt_description": query,
            "description": query,
            "color": "white",
            "urls": {"regular": f"https://images.test/{photo_id}.jpg"},
            "links": {},
            "tags": [{"title": token} for token in query.split()[:3]],
            "user": {"name": "Mock Photographer"},
        }]

    async def fake_download(_runtime, _client, image_url):
        rng = random.Random(image_url)
        image = Image.new("L", (9, 8))
        image.putdata([rng.randrange(256) for _ in range(72)])
        image = image.resize((90, 80))
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        return buffer.getvalue(), "image/png"

    class FakeGroq:
        def __init__(self, _settings):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args):
            return None

        async def review_catalog_candidate(self, *, image_url, brief, photo_context):
            suffix = photo_context["photoId"][:8]
            return {
                "name": f"Catalog {suffix}",
                "description": f"A clearly visible {brief['concept']} product.",
                "category": brief["category"],
                "objectType": brief["concept"],
                "colors": ["white"],
                "materials": ["cotton"],
                "style": ["minimal"],
                "tags": [brief["concept"]],
                "confidence": 0.92,
                "rejectionReasons": [],
                "heroImageSuitable": True,
            }

    class FakeGemini:
        def __init__(self, _settings):
            pass

        async def verify_catalog_candidate(self, *, image, mime_type, brief, photo_context):
            return {
                "category": brief["category"],
                "objectType": brief["concept"],
                "colors": ["white"],
                "materials": ["cotton"],
                "style": ["minimal"],
                "tags": [brief["concept"]],
                "confidence": 0.9,
                "rejectionReasons": [],
                "heroImageSuitable": True,
                "titleSupported": True,
                "descriptionSupported": True,
                "correctedName": photo_context["proposedName"],
                "correctedDescription": photo_context["proposedDescription"],
            }

    monkeypatch.setattr(importer, "fetch_unsplash", fake_search)
    monkeypatch.setattr(importer, "download_image", fake_download)
    monkeypatch.setattr(importer, "GroqClient", FakeGroq)
    monkeypatch.setattr(importer, "GeminiClient", FakeGemini)

    directory = await importer.build_stage(settings, "mocked-full-run")
    products = json.loads((directory / "products.staged.json").read_text(encoding="utf-8"))
    summary = json.loads((directory / "run-summary.json").read_text(encoding="utf-8"))

    assert len(products) == 50
    assert summary["status"] == "staged"
    assert summary["productCount"] == 50
    assert (directory / "products.audit.json").exists()
    assert (directory / "products.audit.md").exists()
    assert (directory / "contact-sheet.html").exists()
    first_run_searches = len(search_calls)

    resumed_directory = await importer.build_stage(settings, "mocked-full-run")

    assert resumed_directory == directory
    assert len(search_calls) == first_run_searches


def test_publish_aborts_oversized_atomic_batch_before_mutation(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path)
    directory = tmp_path / "runs" / "large-run"
    directory.mkdir(parents=True)
    products = [{"id": f"p{index:03d}"} for index in range(1, 51)]
    (directory / "products.staged.json").write_text(json.dumps(products), encoding="utf-8")
    checksum = importer.artifact_checksum(products)
    monkeypatch.setattr(importer, "validate_run", lambda _settings, _run_id: checksum)

    class FakeDoc:
        def __init__(self, doc_id):
            self.id = doc_id
            self.reference = object()

        def to_dict(self):
            return {"value": self.id}

    class FakeCollection:
        def stream(self):
            return [FakeDoc(f"stale-{index}") for index in range(451)]

    class FakeClient:
        def collection(self, _name):
            return FakeCollection()

        def batch(self):
            pytest.fail("No Firestore batch may be created after the size gate fails")

    monkeypatch.setattr(importer, "firestore_client", lambda _settings: FakeClient())

    with pytest.raises(CatalogSeedError, match="Firestore limit"):
        importer.publish_run(settings, "large-run", checksum)
