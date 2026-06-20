from __future__ import annotations

import json
from copy import deepcopy
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from backend.app.api.v1.dependencies import get_checkout_service
from backend.app.core.config import get_settings
from backend.app.main import create_app
from backend.app.services.checkout_service import CheckoutService
from backend.app.tests.conftest import AUTH_HEADERS


ADDRESS = {
    "line1": "123 Main St",
    "line2": None,
    "city": "Austin",
    "region": "TX",
    "postalCode": "78701",
    "country": "US",
}


class MemoryCheckoutRepository:
    def __init__(self) -> None:
        self.cart = [{"productId": "p017", "quantity": 1}]
        self.orders: dict[str, dict] = {}
        self.inventory = 5
        self.confirm_calls = 0

    def price_cart(self, uid: str) -> tuple[list[dict], int]:
        return [], 6400

    def confirm_order(
        self,
        *,
        uid: str,
        payment_intent_id: str,
        paid_amount: int,
        currency: str,
        shipping_address: dict,
    ) -> dict:
        key = f"{uid}:{payment_intent_id}"
        if key in self.orders:
            return deepcopy(self.orders[key])
        self.confirm_calls += 1
        order = {
            "orderId": "o_existing",
            "orderNumber": "HUL-20260619-0001",
            "items": [],
            "total": paid_amount / 100,
            "currency": currency,
            "status": "confirmed",
            "shippingAddress": shipping_address,
            "paymentIntentId": payment_intent_id,
            "createdAt": datetime.now(timezone.utc),
        }
        self.orders[key] = order
        self.inventory -= 1
        self.cart.clear()
        return deepcopy(order)

    def get_orders(self, uid: str) -> list[dict]:
        return list(self.orders.values())


class FakeStripeClient:
    def __init__(self, status: str = "succeeded") -> None:
        self.status = status
        self.created: list[dict] = []

    def create_payment_intent(self, **kwargs) -> dict:
        self.created.append(kwargs)
        return {"id": "pi_safe", "client_secret": "pi_safe_secret"}

    def retrieve_payment_intent(self, payment_intent_id: str) -> dict:
        return {
            "id": payment_intent_id,
            "status": self.status,
            "amount": 6400,
            "currency": "usd",
            "metadata": {
                "uid": "u_001",
                "shippingAddress": json.dumps(ADDRESS),
            },
        }


def _client(monkeypatch, repository, stripe_client) -> TestClient:
    monkeypatch.setenv("HUAL_AUTH_ALLOW_TEST_TOKENS", "true")
    get_settings.cache_clear()
    service = CheckoutService(repository, stripe_client)
    app = create_app()
    app.dependency_overrides[get_checkout_service] = lambda: service
    return TestClient(app)


def test_create_payment_intent_uses_only_server_cart_amount(monkeypatch) -> None:
    repository = MemoryCheckoutRepository()
    stripe_client = FakeStripeClient()
    client = _client(monkeypatch, repository, stripe_client)

    response = client.post(
        "/create-payment-intent",
        headers=AUTH_HEADERS,
        json={"shippingAddress": ADDRESS},
    )

    assert response.status_code == 200
    assert response.json()["amount"] == 6400
    assert stripe_client.created[0]["amount"] == 6400


def test_create_payment_intent_rejects_client_total(monkeypatch) -> None:
    repository = MemoryCheckoutRepository()
    stripe_client = FakeStripeClient()
    client = _client(monkeypatch, repository, stripe_client)

    response = client.post(
        "/create-payment-intent",
        headers=AUTH_HEADERS,
        json={"shippingAddress": ADDRESS, "amount": 1, "total": 0.01},
    )

    assert response.status_code == 422
    assert stripe_client.created == []


def test_duplicate_confirm_returns_existing_order(monkeypatch) -> None:
    repository = MemoryCheckoutRepository()
    client = _client(monkeypatch, repository, FakeStripeClient())
    payload = {"paymentIntentId": "pi_duplicate"}

    first = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)
    second = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["orderId"] == first.json()["orderId"]
    assert len(repository.orders) == 1
    assert repository.confirm_calls == 1
    assert repository.inventory == 4


def test_failed_payment_preserves_cart_and_creates_no_order(monkeypatch) -> None:
    repository = MemoryCheckoutRepository()
    client = _client(monkeypatch, repository, FakeStripeClient(status="requires_payment_method"))

    response = client.post(
        "/orders/confirm",
        headers=AUTH_HEADERS,
        json={"paymentIntentId": "pi_failed_card"},
    )

    assert response.status_code == 402
    assert response.json()["error"] == "payment_not_succeeded"
    assert repository.cart == [{"productId": "p017", "quantity": 1}]
    assert repository.orders == {}
    assert repository.inventory == 5
