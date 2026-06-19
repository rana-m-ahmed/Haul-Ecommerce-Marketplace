from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Protocol

from backend.app.core.config import Settings
from backend.app.core.firebase import initialize_firebase
from backend.app.services.tokenizer import search_tokens


ROOT = Path(__file__).resolve().parents[3]
SEED_PATH = ROOT / "backend" / "seed" / "products.json"


class CatalogRepository(Protocol):
    def list_products(self) -> list[dict]:
        ...

    def get_product(self, product_id: str) -> dict | None:
        ...


def normalize_product(product: dict) -> dict:
    normalized = deepcopy(product)
    normalized["searchTokens"] = search_tokens(
        str(normalized.get("name", "")),
        [str(tag) for tag in normalized.get("tags", [])],
    )
    return normalized


class LocalSeedCatalogRepository:
    def __init__(self, seed_path: Path = SEED_PATH) -> None:
        self.seed_path = seed_path
        self._products: list[dict] | None = None

    def _load(self) -> list[dict]:
        if self._products is None:
            with self.seed_path.open("r", encoding="utf-8") as handle:
                self._products = [normalize_product(product) for product in json.load(handle)]
        return self._products

    def list_products(self) -> list[dict]:
        return [deepcopy(product) for product in self._load()]

    def get_product(self, product_id: str) -> dict | None:
        for product in self._load():
            if product["id"] == product_id:
                return deepcopy(product)
        return None


class FirestoreCatalogRepository:
    def __init__(self, settings: Settings) -> None:
        if os.environ.get("FIRESTORE_EMULATOR_HOST"):
            from google.auth.credentials import AnonymousCredentials
            from google.cloud import firestore

            self.client = firestore.Client(
                project=settings.firebase_project_id or "hual-local",
                credentials=AnonymousCredentials(),
            )
            return

        initialize_firebase(settings)
        from firebase_admin import firestore

        self.client = firestore.client()

    def list_products(self) -> list[dict]:
        return [normalize_product(snapshot.to_dict() | {"id": snapshot.id}) for snapshot in self.client.collection("products").stream()]

    def get_product(self, product_id: str) -> dict | None:
        snapshot = self.client.collection("products").document(product_id).get()
        if not snapshot.exists:
            return None
        return normalize_product(snapshot.to_dict() | {"id": snapshot.id})


def catalog_repository(settings: Settings) -> CatalogRepository:
    if settings.firebase_project_id or settings.firebase_service_account_json:
        try:
            return FirestoreCatalogRepository(settings)
        except Exception:
            return LocalSeedCatalogRepository()
    return LocalSeedCatalogRepository()
