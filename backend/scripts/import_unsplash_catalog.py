from __future__ import annotations

import argparse
import asyncio
from dataclasses import asdict
from datetime import UTC, datetime
from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import sys
import time
from typing import Any, Awaitable, Callable
from uuid import uuid4

import httpx

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.core.config import Settings, get_settings
from backend.app.core.firebase import initialize_firebase
from backend.app.core.gemini_client import GeminiClient
from backend.app.core.groq_client import GroqClient
from backend.app.services.catalog_reseed import (
    CandidateEvaluation,
    CatalogBrief,
    CatalogSeedError,
    UnsplashCandidate,
    build_audit_entry,
    build_photo_context,
    build_unsplash_queries,
    canonical_image_url,
    compose_staged_product,
    evaluate_image_hash,
    image_sha256,
    is_candidate_viable,
    load_blueprints,
    parse_unsplash_candidate,
    render_audit_markdown,
    render_contact_sheet,
    score_candidate,
    select_assignments,
    validate_staged_catalog,
)
from backend.app.services.catalog_run_store import CatalogRunStore


PROMPT_VERSION = "catalog-v3"
RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}


class UnsplashQuotaExhausted(CatalogSeedError):
    pass


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def resolve_path(value: str | Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else ROOT / path


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(value, encoding="utf-8")
    os.replace(temporary, path)


def artifact_checksum(products: list[dict[str, Any]]) -> str:
    encoded = json.dumps(_json_safe(products), sort_keys=True, separators=(",", ":")).encode("utf-8")
    return sha256(encoded).hexdigest()


def _json_safe(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat().replace("+00:00", "Z")
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def run_fingerprint(blueprint_path: Path, settings: Settings) -> str:
    payload = b"|".join(
        [blueprint_path.read_bytes(), settings.groq_model.encode(), settings.gemini_model.encode(), PROMPT_VERSION.encode()]
    )
    return sha256(payload).hexdigest()


def run_directory(settings: Settings, run_id: str) -> Path:
    return resolve_path(settings.catalog_runs_path) / run_id


class StageRuntime:
    def __init__(self, settings: Settings, store: CatalogRunStore) -> None:
        self.settings = settings
        self.store = store
        self.unsplash_semaphore = asyncio.Semaphore(8)
        self.groq_semaphore = asyncio.Semaphore(2)
        self.gemini_semaphore = asyncio.Semaphore(2)
        self.provider_failures = {"unsplash": 0, "groq": 0, "gemini": 0}
        self.inflight_budget = {"groq": 0, "gemini": 0}
        self.started = time.monotonic()

    def progress(self, message: str) -> None:
        elapsed = int(time.monotonic() - self.started)
        rendered = f"[{elapsed:04d}s] {message}"
        print(rendered, flush=True)
        self.store.event("info", rendered)
        self.store.set_meta("updated_at", utc_now())

    def reserve(self, provider: str, limit: int) -> None:
        count = int(self.store.get_meta(f"{provider}_requests", 0)) + self.inflight_budget.get(provider, 0)
        if count >= limit:
            raise CatalogSeedError(f"{provider} request budget exceeded ({limit})")

    async def provider_call(
        self,
        provider: str,
        semaphore: asyncio.Semaphore,
        operation: Callable[[], Awaitable[Any]],
        *,
        budget: int | None = None,
    ) -> Any:
        if self.provider_failures[provider] >= 3:
            raise CatalogSeedError(f"{provider} circuit breaker is open after three consecutive failures")
        if budget is not None:
            self.reserve(provider, budget)
            self.inflight_budget[provider] += 1
        try:
            async with semaphore:
                result = await operation()
            self.provider_failures[provider] = 0
            if budget is not None:
                self.store.increment(f"{provider}_requests")
            return result
        except UnsplashQuotaExhausted:
            # Quota exhaustion is a resumable scheduler state, not provider instability.
            raise
        except Exception:
            self.provider_failures[provider] += 1
            raise
        finally:
            if budget is not None:
                self.inflight_budget[provider] -= 1


async def fetch_unsplash(
    runtime: StageRuntime,
    client: httpx.AsyncClient,
    query: str,
    *,
    page: int = 1,
    per_page: int = 8,
) -> list[dict[str, Any]]:
    cached = runtime.store.search(query)
    if cached is not None:
        runtime.progress(f"Unsplash cache hit query={query}")
        return cached

    async def operation() -> list[dict[str, Any]]:
        runtime.store.increment("unsplash_requests")
        response = await client.get(
            f"{runtime.settings.unsplash_api_base_url.rstrip('/')}/search/photos",
            params={"query": query, "page": page, "per_page": per_page, "orientation": "portrait", "content_filter": "high"},
            headers={"Authorization": f"Client-ID {runtime.settings.unsplash_access_key}", "Accept-Version": "v1"},
        )
        remaining = response.headers.get("x-ratelimit-remaining")
        reset = response.headers.get("x-ratelimit-reset")
        if remaining is not None:
            runtime.store.set_meta("unsplash_remaining", remaining)
        if reset is not None:
            runtime.store.set_meta("unsplash_reset", reset)
        if response.status_code == 403 and remaining == "0":
            raise UnsplashQuotaExhausted(f"Unsplash quota exhausted; reset={reset or 'unknown'}")
        response.raise_for_status()
        payload = response.json().get("results", [])
        results = payload if isinstance(payload, list) else []
        runtime.store.save_search(query, results)
        return results

    return await runtime.provider_call("unsplash", runtime.unsplash_semaphore, operation)


async def download_image(runtime: StageRuntime, client: httpx.AsyncClient, image_url: str) -> tuple[bytes, str]:
    async def operation() -> tuple[bytes, str]:
        response = await client.get(image_url, follow_redirects=True)
        response.raise_for_status()
        content_type = response.headers.get("content-type", "image/jpeg")
        if not content_type.startswith("image/"):
            raise CatalogSeedError(f"Non-image response for {canonical_image_url(image_url)}")
        return response.content, content_type

    return await runtime.provider_call("unsplash", runtime.unsplash_semaphore, operation)


def candidate_rank(candidate: UnsplashCandidate, brief: CatalogBrief) -> tuple[int, int, int]:
    context = " ".join([candidate.alt_description or "", candidate.description or "", *candidate.tags]).lower()
    terms = set(brief.concept.split()) | {token for value in brief.expected_attributes for token in value.split()}
    coverage = sum(1 for term in terms if term in context)
    return coverage, candidate.likes, candidate.width * candidate.height


def local_candidate_ok(candidate: UnsplashCandidate) -> bool:
    return candidate.width >= 1000 and candidate.height >= 1200 and candidate.height >= candidate.width


def evaluation_record(evaluation: CandidateEvaluation, *, status: str = "accepted") -> dict[str, Any]:
    return {
        "status": status,
        "brief": asdict(evaluation.brief),
        "candidate": asdict(evaluation.candidate),
        "groqReview": evaluation.groq_review,
        "geminiReview": evaluation.gemini_review,
        "compositeScore": evaluation.composite_score,
        "imageHash": evaluation.image_hash,
        "byteHash": evaluation.byte_hash,
        "mimeType": evaluation.mime_type,
    }


def evaluation_from_record(record: dict[str, Any]) -> CandidateEvaluation:
    brief_payload = record["brief"]
    candidate_payload = record["candidate"]
    return CandidateEvaluation(
        slot_id=brief_payload["slot_id"],
        brief=CatalogBrief(**brief_payload),
        candidate=UnsplashCandidate(**candidate_payload),
        groq_review=record["groqReview"],
        gemini_review=record["geminiReview"],
        composite_score=float(record["compositeScore"]),
        image_hash=record["imageHash"],
        photo_context=build_photo_context(UnsplashCandidate(**candidate_payload)),
        image_bytes=b"",
        mime_type=record.get("mimeType", "image/jpeg"),
        byte_hash=record["byteHash"],
    )


async def evaluate_slot(
    runtime: StageRuntime,
    http_client: httpx.AsyncClient,
    groq: GroqClient,
    gemini: GeminiClient,
    brief: CatalogBrief,
    *,
    refined: bool = False,
    ignore_cache: bool = False,
) -> list[CandidateEvaluation]:
    stored_records = runtime.store.candidates(brief.slot_id)
    cached: list[CandidateEvaluation] = []
    for item in stored_records:
        if not item.get("geminiReview"):
            continue
        evaluation = evaluation_from_record(item)
        viable, _ = is_candidate_viable(evaluation)
        if viable:
            runtime.store.save_candidate(brief.slot_id, evaluation.candidate.photo_id, evaluation_record(evaluation))
            cached.append(evaluation)
    records_by_photo = {item.get("candidate", {}).get("photo_id"): item for item in stored_records}
    if cached and not ignore_cache:
        runtime.progress(f"{brief.slot_id} resumed with {len(cached)} cached viable candidate(s)")
        runtime.store.set_slot(brief.slot_id, "evaluated")
        return cached

    runtime.store.set_slot(brief.slot_id, "searching")
    queries = build_unsplash_queries(brief, refined=refined)
    if refined:
        queries = queries[-2:]
    payloads: dict[str, tuple[dict[str, Any], str]] = {}
    for query in queries[:3]:
        try:
            search_results = await fetch_unsplash(runtime, http_client, query)
        except UnsplashQuotaExhausted as exc:
            runtime.store.set_slot(brief.slot_id, "waiting_quota", str(exc))
            runtime.progress(f"{brief.slot_id} waiting for Unsplash quota reset")
            return cached
        for payload in search_results:
            photo_id = str(payload.get("id") or payload.get("slug") or "")
            if photo_id and photo_id not in payloads:
                payloads[photo_id] = (payload, query)
            if len(payloads) >= 8:
                break
        if len(payloads) >= 8:
            break

    candidates: list[UnsplashCandidate] = []
    for payload, query in payloads.values():
        try:
            candidate = parse_unsplash_candidate(payload, query)
        except Exception:
            continue
        if local_candidate_ok(candidate):
            candidates.append(candidate)
    candidates.sort(key=lambda item: candidate_rank(item, brief), reverse=True)
    if not candidates:
        runtime.store.set_slot(brief.slot_id, "failed", "no_local_candidates")
        return []

    evaluations: list[CandidateEvaluation] = []
    gemini_attempts = 0
    groq_limit = 2 if refined else 3
    for candidate in candidates[:groq_limit]:
        stored = records_by_photo.get(candidate.photo_id)
        if stored and stored.get("status") == "rejected":
            continue
        try:
            image_bytes, mime_type = await download_image(runtime, http_client, candidate.image_url)
            image_hash = evaluate_image_hash(image_bytes)
            byte_hash = image_sha256(image_bytes)
            context = build_photo_context(candidate)
            brief_payload = {
                "slotId": brief.slot_id,
                "category": brief.category,
                "concept": brief.concept,
                "expectedAttributes": brief.expected_attributes,
                "forbiddenOverlaps": brief.banned_overlap_terms,
            }
            if stored and stored.get("groqReview"):
                groq_review = stored["groqReview"]
                runtime.progress(f"{brief.slot_id} reused Groq review {candidate.photo_id}")
            else:
                groq_review = await runtime.provider_call(
                    "groq",
                    runtime.groq_semaphore,
                    lambda: groq.review_catalog_candidate(image_url=candidate.image_url, brief=brief_payload, photo_context=context),
                    budget=runtime.settings.catalog_groq_budget,
                )
                runtime.store.save_candidate(brief.slot_id, candidate.photo_id, {
                    "status": "groq_reviewed", "brief": asdict(brief), "candidate": asdict(candidate),
                    "groqReview": groq_review, "imageHash": image_hash, "byteHash": byte_hash, "mimeType": mime_type,
                })
                runtime.progress(f"{brief.slot_id} Groq reviewed {candidate.photo_id}")
            groq_passes = (
                groq_review.get("category") == brief.category
                and float(groq_review.get("confidence") or 0) >= 0.80
                and groq_review.get("heroImageSuitable") is True
                and not groq_review.get("rejectionReasons")
            )
            if not groq_passes or gemini_attempts >= 2:
                continue
            gemini_attempts += 1
            verify_context = context | {
                "proposedName": groq_review.get("name"),
                "proposedDescription": groq_review.get("description"),
                "proposedObjectType": groq_review.get("objectType"),
            }
            gemini_review = await runtime.provider_call(
                "gemini",
                runtime.gemini_semaphore,
                lambda: gemini.verify_catalog_candidate(
                    image=image_bytes,
                    mime_type=mime_type,
                    brief=brief_payload,
                    photo_context=verify_context,
                ),
                budget=runtime.settings.catalog_gemini_budget,
            )
            evaluation = CandidateEvaluation(
                slot_id=brief.slot_id,
                brief=brief,
                candidate=candidate,
                groq_review=groq_review,
                gemini_review=gemini_review,
                composite_score=score_candidate(groq_review, gemini_review),
                image_hash=image_hash,
                photo_context=verify_context,
                image_bytes=image_bytes,
                mime_type=mime_type,
                byte_hash=byte_hash,
            )
            viable, reasons = is_candidate_viable(evaluation)
            runtime.progress(f"{brief.slot_id} Gemini verified {candidate.photo_id}: {'accepted' if viable else ','.join(reasons)}")
            runtime.store.save_candidate(
                brief.slot_id,
                candidate.photo_id,
                evaluation_record(evaluation, status="accepted" if viable else "rejected"),
            )
            if viable:
                evaluations.append(evaluation)
        except CatalogSeedError:
            raise
        except Exception as exc:
            runtime.progress(f"{brief.slot_id} rejected {candidate.photo_id}: {type(exc).__name__}")

    if not evaluations and not refined:
        runtime.progress(f"{brief.slot_id} starting targeted refill")
        return await evaluate_slot(runtime, http_client, groq, gemini, brief, refined=True, ignore_cache=True)
    if not evaluations:
        runtime.store.set_slot(brief.slot_id, "failed", "no_consensus_candidate")
    else:
        runtime.store.set_slot(brief.slot_id, "evaluated")
    return evaluations


async def heartbeat(runtime: StageRuntime) -> None:
    while True:
        await asyncio.sleep(10)
        summary = runtime.store.summary()
        runtime.progress(f"heartbeat slots={summary['slots']} requests={summary['requests']}")


async def build_stage(settings: Settings, run_id: str) -> Path:
    blueprint_path = resolve_path(settings.catalog_blueprint_path)
    manifest, briefs, _ = load_blueprints(blueprint_path)
    directory = run_directory(settings, run_id)
    directory.mkdir(parents=True, exist_ok=True)
    store = CatalogRunStore(directory / "state.sqlite3")
    fingerprint = run_fingerprint(blueprint_path, settings)
    previous = store.get_meta("fingerprint")
    if previous and previous != fingerprint:
        store.close()
        raise CatalogSeedError("Run fingerprint changed; start a new run instead of resuming stale provider results")
    store.set_meta("run_id", run_id)
    store.set_meta("fingerprint", fingerprint)
    store.set_meta("started_at", store.get_meta("started_at", utc_now()))
    response_counts = store.provider_response_counts()
    store.set_meta("groq_requests", response_counts["groq"])
    store.set_meta("gemini_requests", response_counts["gemini"])
    store.set_meta("status", "running")
    runtime = StageRuntime(settings, store)
    timeout = settings.catalog_deadline_minutes * 60

    async def execute() -> None:
        timeout_config = httpx.Timeout(settings.catalog_request_timeout_seconds)
        async with httpx.AsyncClient(timeout=timeout_config) as http_client, GroqClient(settings) as groq:
            gemini = GeminiClient(settings)
            heartbeat_task = asyncio.create_task(heartbeat(runtime))
            try:
                tasks = [asyncio.create_task(evaluate_slot(runtime, http_client, groq, gemini, briefs[slot.id])) for slot in manifest]
                try:
                    slot_results = await asyncio.gather(*tasks)
                except BaseException:
                    for task in tasks:
                        task.cancel()
                    await asyncio.gather(*tasks, return_exceptions=True)
                    raise
            finally:
                heartbeat_task.cancel()
                await asyncio.gather(heartbeat_task, return_exceptions=True)
            evaluations_by_slot = {slot.id: values for slot, values in zip(manifest, slot_results)}
            chosen, diagnostics = select_assignments(
                manifest=manifest, briefs=briefs, evaluations_by_slot=evaluations_by_slot
            )
            missing = [slot.id for slot in manifest if slot.id not in chosen]
            waiting_quota = [row["slot_id"] for row in store.slots() if row["status"] == "waiting_quota"]
            if missing and waiting_quota:
                raise UnsplashQuotaExhausted(
                    f"Unsplash quota paused slots: {', '.join(waiting_quota)}; resume run {run_id} after reset"
                )
            if missing:
                runtime.progress(f"global assignment requested refill for {','.join(missing)}")
                for slot_id in missing:
                    more = await evaluate_slot(
                        runtime, http_client, groq, gemini, briefs[slot_id], refined=True, ignore_cache=True
                    )
                    known = {item.candidate.photo_id for item in evaluations_by_slot[slot_id]}
                    evaluations_by_slot[slot_id].extend(item for item in more if item.candidate.photo_id not in known)
                chosen, diagnostics = select_assignments(manifest=manifest, briefs=briefs, evaluations_by_slot=evaluations_by_slot)
                missing = [slot.id for slot in manifest if slot.id not in chosen]
            if missing:
                raise CatalogSeedError(f"Unable to assign a unique passing candidate to: {', '.join(missing)}")

            products: list[dict[str, Any]] = []
            audits: list[dict[str, Any]] = []
            for slot in manifest:
                evaluation = chosen[slot.id]
                if evaluation.candidate.download_location:
                    response = await runtime.provider_call(
                        "unsplash",
                        runtime.unsplash_semaphore,
                        lambda location=evaluation.candidate.download_location: http_client.get(
                            location,
                            headers={"Authorization": f"Client-ID {settings.unsplash_access_key}", "Accept-Version": "v1"},
                        ),
                    )
                    response.raise_for_status()
                product = compose_staged_product(slot, evaluation)
                audit = build_audit_entry(slot, evaluation, diagnostics=diagnostics)
                audit["imageHash"] = evaluation.image_hash
                audit["byteHash"] = evaluation.byte_hash
                products.append(product)
                audits.append(audit)
        validate_staged_catalog(manifest=manifest, products=products, audits=audits)
        checksum = artifact_checksum(products)
        write_json(directory / "products.staged.json", products)
        write_json(directory / "products.audit.json", audits)
        write_text(directory / "products.audit.md", render_audit_markdown(audits))
        write_text(directory / "contact-sheet.html", render_contact_sheet(audits))
        store.set_meta("checksum", checksum)
        store.set_meta("status", "staged")
        write_json(directory / "run-summary.json", store.summary() | {"checksum": checksum, "productCount": len(products)})
        runtime.progress(f"stage complete products=50 checksum={checksum}")

    try:
        await asyncio.wait_for(execute(), timeout=timeout)
    except asyncio.TimeoutError:
        store.set_meta("status", "timed_out")
        store.event("error", f"Run exceeded the {settings.catalog_deadline_minutes}-minute deadline")
        raise CatalogSeedError(f"Run timed out; resume with: stage --run-id {run_id}") from None
    except BaseException as exc:
        if isinstance(exc, UnsplashQuotaExhausted):
            final_status = "waiting_quota"
        elif isinstance(exc, (KeyboardInterrupt, asyncio.CancelledError)):
            final_status = "interrupted"
        else:
            final_status = "failed"
        store.set_meta("status", final_status)
        store.event("error", str(exc))
        raise
    finally:
        store.set_meta("updated_at", utc_now())
        store.close()
    return directory


async def preflight(settings: Settings) -> None:
    blueprint_path = resolve_path(settings.catalog_blueprint_path)
    manifest, _, _ = load_blueprints(blueprint_path)
    missing = [name for name, value in {
        "HUAL_UNSPLASH_ACCESS_KEY": settings.unsplash_access_key,
        "HUAL_GROQ_API_KEY": settings.groq_api_key,
        "HUAL_GEMINI_API_KEY": settings.gemini_api_key,
        "HUAL_FIREBASE_PROJECT_ID": settings.firebase_project_id,
    }.items() if not value]
    if missing:
        raise CatalogSeedError(f"Missing configuration: {', '.join(missing)}")
    async with httpx.AsyncClient(timeout=settings.catalog_request_timeout_seconds) as client, GroqClient(settings) as groq:
        response = await client.get(
            f"{settings.unsplash_api_base_url.rstrip('/')}/search/photos",
            params={"query": "product", "per_page": 1},
            headers={"Authorization": f"Client-ID {settings.unsplash_access_key}"},
        )
        response.raise_for_status()
        await groq.probe()
        await GeminiClient(settings).probe()
    initialize_firebase(settings)
    from firebase_admin import firestore
    list(firestore.client().collection("products").limit(1).stream())
    print(json.dumps({
        "status": "ok", "blueprints": len(manifest), "groqModel": settings.groq_model,
        "geminiModel": settings.gemini_model, "unsplashRemaining": response.headers.get("x-ratelimit-remaining"),
        "firebaseProject": settings.firebase_project_id,
    }, indent=2), flush=True)


def validate_run(settings: Settings, run_id: str) -> str:
    directory = run_directory(settings, run_id)
    products = json.loads((directory / "products.staged.json").read_text(encoding="utf-8"))
    audits = json.loads((directory / "products.audit.json").read_text(encoding="utf-8"))
    checksum = artifact_checksum(products)
    store = CatalogRunStore(directory / "state.sqlite3")
    try:
        if store.get_meta("checksum") != checksum or store.get_meta("status") != "staged":
            raise CatalogSeedError("Staged artifact checksum or status does not match its run state")
    finally:
        store.close()
    manifest, _, _ = load_blueprints(resolve_path(settings.catalog_blueprint_path))
    validate_staged_catalog(manifest=manifest, products=products, audits=audits)
    print(f"validated products=50 checksum={checksum}", flush=True)
    return checksum


def firestore_client(settings: Settings):
    initialize_firebase(settings)
    from firebase_admin import firestore
    return firestore.client()


def read_collection(client, name: str) -> list[dict[str, Any]]:
    return [snapshot.to_dict() | {"id": snapshot.id} for snapshot in client.collection(name).stream()]


def publish_run(settings: Settings, run_id: str, approved_checksum: str) -> Path:
    checksum = validate_run(settings, run_id)
    if approved_checksum != checksum:
        raise CatalogSeedError("Approved checksum does not match the validated staged catalog")
    directory = run_directory(settings, run_id)
    products = json.loads((directory / "products.staged.json").read_text(encoding="utf-8"))
    client = firestore_client(settings)
    existing_docs = list(client.collection("products").stream())
    backup = [doc.to_dict() | {"id": doc.id} for doc in existing_docs]
    backup_path = directory / f"products.backup.{datetime.now(UTC).strftime('%Y%m%dT%H%M%SZ')}.json"
    write_json(backup_path, backup)
    json.loads(backup_path.read_text(encoding="utf-8"))

    keep_ids = {product["id"] for product in products}
    stale = [doc for doc in existing_docs if doc.id not in keep_ids]
    operation_count = len(products) + len(stale) + 1
    if operation_count > 500:
        raise CatalogSeedError(f"Atomic publish requires {operation_count} writes; Firestore limit is 500")
    batch = client.batch()
    for product in products:
        batch.set(client.collection("products").document(product["id"]), product)
    for doc in stale:
        batch.delete(doc.reference)
    batch.set(client.collection("catalogMetadata").document("current"), {
        "runId": run_id, "checksum": checksum, "productCount": 50,
        "groqModel": settings.groq_model, "geminiModel": settings.gemini_model,
        "publishedAt": datetime.now(UTC),
    })
    batch.commit()

    published = read_collection(client, "products")
    published.sort(key=lambda item: item["id"])
    if [item["id"] for item in published] != [f"p{index:03d}" for index in range(1, 51)]:
        raise CatalogSeedError("Post-publish Firestore ID verification failed; backup is available")
    if artifact_checksum(published) != checksum:
        raise CatalogSeedError("Post-publish Firestore checksum verification failed; backup is available")
    manifest, _, _ = load_blueprints(resolve_path(settings.catalog_blueprint_path))
    audits = json.loads((directory / "products.audit.json").read_text(encoding="utf-8"))
    validate_staged_catalog(manifest=manifest, products=published, audits=audits)

    canonical_seed = ROOT / "backend" / "seed" / "products.json"
    shutil.copy2(canonical_seed, directory / "products.local.backup.json")
    write_json(canonical_seed, products)
    store = CatalogRunStore(directory / "state.sqlite3")
    store.set_meta("status", "published")
    store.set_meta("published_at", utc_now())
    store.close()
    print(f"published products=50 deleted_stale={len(stale)} backup={backup_path}", flush=True)
    return backup_path


def rollback(settings: Settings, backup_path: Path) -> None:
    path = backup_path.resolve()
    seed_root = (ROOT / "backend" / "seed").resolve()
    if seed_root not in path.parents or not path.name.startswith("products.backup."):
        raise CatalogSeedError("Rollback backup must be a products.backup file under backend/seed")
    products = json.loads(path.read_text(encoding="utf-8"))
    client = firestore_client(settings)
    current = list(client.collection("products").stream())
    keep = {product["id"] for product in products}
    stale = [doc for doc in current if doc.id not in keep]
    if len(products) + len(stale) > 500:
        raise CatalogSeedError("Rollback exceeds Firestore atomic batch limit")
    batch = client.batch()
    for product in products:
        batch.set(client.collection("products").document(product["id"]), product)
    for doc in stale:
        batch.delete(doc.reference)
    batch.commit()
    print(f"rollback restored={len(products)} removed={len(stale)}", flush=True)


def status(settings: Settings, run_id: str) -> None:
    state_path = run_directory(settings, run_id) / "state.sqlite3"
    if not state_path.exists():
        raise CatalogSeedError(f"Unknown run ID: {run_id}")
    store = CatalogRunStore(state_path)
    try:
        print(json.dumps(store.summary(), indent=2), flush=True)
    finally:
        store.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Bounded, resumable catalog seeding pipeline")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("preflight")
    stage_parser = subparsers.add_parser("stage")
    stage_parser.add_argument("--run-id", default=None)
    for name in ("status", "validate"):
        command_parser = subparsers.add_parser(name)
        command_parser.add_argument("--run-id", required=True)
    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--run-id", required=True)
    publish_parser.add_argument("--approved-checksum", required=True)
    rollback_parser = subparsers.add_parser("rollback")
    rollback_parser.add_argument("--backup", type=Path, required=True)
    args = parser.parse_args()
    settings = get_settings()
    try:
        if args.command == "preflight":
            asyncio.run(preflight(settings))
        elif args.command == "stage":
            run_id = args.run_id or f"{datetime.now(UTC).strftime('%Y%m%dT%H%M%SZ')}-{uuid4().hex[:6]}"
            print(f"run_id={run_id}", flush=True)
            asyncio.run(build_stage(settings, run_id))
        elif args.command == "status":
            status(settings, args.run_id)
        elif args.command == "validate":
            validate_run(settings, args.run_id)
        elif args.command == "publish":
            publish_run(settings, args.run_id, args.approved_checksum)
        elif args.command == "rollback":
            rollback(settings, args.backup)
    except (CatalogSeedError, httpx.HTTPError, json.JSONDecodeError) as exc:
        print(f"catalog seed failed: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
