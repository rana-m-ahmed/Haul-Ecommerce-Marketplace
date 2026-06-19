from __future__ import annotations

from datetime import UTC, datetime
from copy import deepcopy
from typing import Protocol
from uuid import uuid4

from backend.app.core.config import Settings
from backend.app.core.firebase import initialize_firebase


class EventRepository(Protocol):
    def create_event(self, uid: str, payload: dict) -> str:
        ...

    def list_events(self, uid: str) -> list[dict]:
        ...

    def get_user(self, uid: str) -> dict | None:
        ...

    def get_cache(self, collection: str, key: str) -> dict | None:
        ...

    def set_cache(self, collection: str, key: str, payload: dict) -> None:
        ...

    def delete_cache(self, collection: str, key: str) -> None:
        ...


class LocalEventRepository:
    _events: dict[str, list[dict]] = {}
    _users: dict[str, dict] = {"u_001": {"isGuest": False, "preferences": ["home", "minimal", "warm"]}}
    _cache: dict[tuple[str, str], dict] = {}

    def create_event(self, uid: str, payload: dict) -> str:
        event_id = f"e_{datetime.now(UTC).strftime('%Y%m%d')}_{uuid4().hex[:8]}"
        event = deepcopy(payload)
        event["id"] = event_id
        event["timestamp"] = event.get("timestamp") or datetime.now(UTC)
        self._events.setdefault(uid, []).append(event)
        return event_id

    def list_events(self, uid: str) -> list[dict]:
        return deepcopy(self._events.get(uid, []))

    def get_user(self, uid: str) -> dict | None:
        return deepcopy(self._users.get(uid))

    def get_cache(self, collection: str, key: str) -> dict | None:
        return deepcopy(self._cache.get((collection, key)))

    def set_cache(self, collection: str, key: str, payload: dict) -> None:
        self._cache[(collection, key)] = deepcopy(payload)

    def delete_cache(self, collection: str, key: str) -> None:
        self._cache.pop((collection, key), None)


class FirestoreEventRepository:
    def __init__(self, settings: Settings) -> None:
        initialize_firebase(settings)
        from firebase_admin import firestore

        self.firestore = firestore
        self.client = firestore.client()

    def create_event(self, uid: str, payload: dict) -> str:
        event_ref = self.client.collection("users").document(uid).collection("events").document()
        event = dict(payload)
        event["timestamp"] = event.get("timestamp") or datetime.now(UTC)
        event_ref.set(event)
        return event_ref.id

    def list_events(self, uid: str) -> list[dict]:
        query = self.client.collection("users").document(uid).collection("events").order_by(
            "timestamp", direction=self.firestore.Query.DESCENDING
        )
        return [snapshot.to_dict() | {"id": snapshot.id} for snapshot in query.limit(500).stream()]

    def get_user(self, uid: str) -> dict | None:
        snapshot = self.client.collection("users").document(uid).get()
        return snapshot.to_dict() if snapshot.exists else None

    def get_cache(self, collection: str, key: str) -> dict | None:
        snapshot = self.client.collection(collection).document(key).get()
        return snapshot.to_dict() if snapshot.exists else None

    def set_cache(self, collection: str, key: str, payload: dict) -> None:
        self.client.collection(collection).document(key).set(payload)

    def delete_cache(self, collection: str, key: str) -> None:
        self.client.collection(collection).document(key).delete()


def event_repository(settings: Settings) -> EventRepository:
    if settings.firebase_project_id or settings.firebase_service_account_json:
        try:
            return FirestoreEventRepository(settings)
        except Exception:
            return LocalEventRepository()
    return LocalEventRepository()
