from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient

from backend.app.tests.conftest import AUTH_HEADERS


@pytest.mark.skipif(
    not os.environ.get("FIRESTORE_EMULATOR_HOST"),
    reason="Requires the Firestore emulator.",
)
def test_cart_validate_flags_firestore_price_drift(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HUAL_AUTH_ALLOW_TEST_TOKENS", "true")
    monkeypatch.setenv("HUAL_FIREBASE_PROJECT_ID", "hual-cart-validate-test")

    import firebase_admin
    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    from backend.app.api.v1.dependencies import get_cart_service, get_catalog_service, get_event_service
    from backend.app.core.config import get_settings
    from backend.app.main import create_app

    for app in list(firebase_admin._apps.values()):
        firebase_admin.delete_app(app)
    get_settings.cache_clear()
    get_cart_service.cache_clear()
    get_catalog_service.cache_clear()
    get_event_service.cache_clear()

    settings = get_settings()
    db = firestore.Client(project=settings.firebase_project_id, credentials=AnonymousCredentials())
    product_ref = db.collection("products").document("p_firestore_drift")
    product_ref.set(
        {
            "name": "Firestore Drift Lamp",
            "description": "A seeded product for cart validation.",
            "price": 64.0,
            "salePrice": None,
            "category": "home",
            "colors": ["clay"],
            "materials": ["ceramic"],
            "style": ["minimal"],
            "tags": ["lamp"],
            "imageUrls": ["https://hual-assets.web.app/products/p017-1.jpg"],
            "rating": 4.7,
            "reviewCount": 1,
            "inventory": 5,
            "isNew": False,
            "isSale": False,
            "createdAt": "2026-06-17T12:00:00Z",
        }
    )

    client = TestClient(create_app())
    payload = {"items": [{"productId": "p_firestore_drift", "quantity": 1, "priceSnapshot": 64.0}]}
    initial = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert initial.status_code == 200
    assert initial.json()["valid"] is True

    product_ref.update({"price": 58.0})
    drifted = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert drifted.status_code == 200
    assert drifted.json()["valid"] is False
    assert drifted.json()["changes"] == [
        {
            "productId": "p_firestore_drift",
            "variantId": None,
            "reason": "price_changed",
            "oldPrice": 64.0,
            "newPrice": 58.0,
            "oldQuantity": None,
            "newQuantity": None,
        }
    ]
