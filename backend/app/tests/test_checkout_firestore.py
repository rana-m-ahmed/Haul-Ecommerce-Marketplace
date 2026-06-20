from __future__ import annotations

import json
import os

import pytest
from fastapi.testclient import TestClient

from backend.app.tests.conftest import AUTH_HEADERS


@pytest.mark.skipif(
    not os.environ.get("FIRESTORE_EMULATOR_HOST"),
    reason="Requires the Firestore emulator.",
)
def test_confirm_is_atomic_and_idempotent_in_firestore(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HUAL_AUTH_ALLOW_TEST_TOKENS", "true")
    monkeypatch.setenv("HUAL_FIREBASE_PROJECT_ID", "haul-4d155")

    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    from backend.app.api.v1.dependencies import get_checkout_service
    from backend.app.core.config import get_settings
    from backend.app.main import create_app
    from backend.app.services.checkout_repository import FirestoreCheckoutRepository
    from backend.app.services.checkout_service import CheckoutService

    get_settings.cache_clear()
    get_checkout_service.cache_clear()
    settings = get_settings()
    db = firestore.Client(project=settings.firebase_project_id, credentials=AnonymousCredentials())
    for snapshot in db.collection("products").stream():
        snapshot.reference.delete()
    for snapshot in db.collection("users").document("u_001").collection("cart").stream():
        snapshot.reference.delete()
    for snapshot in db.collection("users").document("u_001").collection("orders").stream():
        snapshot.reference.delete()

    db.collection("products").document("p017").set(
        {"name": "Arc Lamp", "price": 64.0, "salePrice": None, "inventory": 5}
    )
    db.collection("users").document("u_001").collection("cart").document("p017").set(
        {"productId": "p017", "variantId": None, "quantity": 1, "priceSnapshot": 64.0}
    )

    class SucceededStripe:
        status = "requires_payment_method"

        def retrieve_payment_intent(self, payment_intent_id: str) -> dict:
            return {
                "id": payment_intent_id,
                "status": self.status,
                "amount": 6400,
                "currency": "usd",
                "metadata": {
                    "uid": "u_001",
                    "shippingAddress": json.dumps(
                        {"line1": "1 Main", "line2": None, "city": "Austin", "region": "TX",
                         "postalCode": "78701", "country": "US"}
                    ),
                },
            }

    stripe_client = SucceededStripe()
    service = CheckoutService(FirestoreCheckoutRepository(settings), stripe_client)
    app = create_app()
    app.dependency_overrides[get_checkout_service] = lambda: service
    client = TestClient(app)
    payload = {"paymentIntentId": "pi_emulator_duplicate"}

    failed = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)
    assert failed.status_code == 402
    assert len(list(db.collection("users").document("u_001").collection("orders").stream())) == 0
    assert len(list(db.collection("users").document("u_001").collection("cart").stream())) == 1
    assert db.collection("products").document("p017").get().to_dict()["inventory"] == 5

    stripe_client.status = "succeeded"
    first = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)
    second = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)

    orders = list(db.collection("users").document("u_001").collection("orders").stream())
    cart = list(db.collection("users").document("u_001").collection("cart").stream())
    product = db.collection("products").document("p017").get().to_dict()
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["orderId"] == first.json()["orderId"]
    assert len(orders) == 1
    assert cart == []
    assert product["inventory"] == 4
