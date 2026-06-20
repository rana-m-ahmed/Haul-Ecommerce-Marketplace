from __future__ import annotations

import pytest

from backend.app.schemas import generated
from backend.app.tests.conftest import AUTH_HEADERS


def assert_model(model, payload: dict) -> None:
    model.model_validate(payload)


def test_health_returns_real_timestamp(client) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.HealthResponse, body)
    assert body["status"] == "ok"
    assert body["version"] == "0.1.0"
    assert body["timestamp"].endswith("Z")


def test_authenticated_routes_require_firebase_token(client) -> None:
    response = client.post("/search", json={})
    assert response.status_code == 401
    assert_model(generated.ApiError, response.json())
    assert response.json()["error"] == "missing_auth"


@pytest.mark.parametrize(
    "payload,expected_ids",
    [
        ({"query": "lamp", "pageSize": 12}, ["p017", "p015"]),
        ({"category": "home", "pageSize": 50}, ["p017", "p018", "p019", "p020", "p021", "p022", "p023", "p024", "p025"]),
        ({"colors": ["white"], "pageSize": 50}, ["p008", "p010", "p015", "p017", "p026", "p028", "p034", "p039"]),
        ({"materials": ["ceramic"], "pageSize": 50}, ["p017"]),
        ({"tags": ["sale"], "pageSize": 50}, ["p002", "p005", "p009", "p010", "p014", "p018", "p022", "p027", "p030", "p034", "p038", "p043", "p047"]),
        ({"minPrice": 20.0, "maxPrice": 30.0, "pageSize": 50}, ["p022", "p028", "p029", "p031", "p032", "p033", "p037", "p047", "p048", "p050"]),
    ],
)
def test_search_filters(client, payload: dict, expected_ids: list[str]) -> None:
    response = client.post("/search", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.SearchResponse, body)
    assert [product["id"] for product in body["products"]] == expected_ids
    assert body["total"] == len(expected_ids)


@pytest.mark.parametrize(
    "sort_by,expected_ids",
    [
        ("newest", ["p024", "p019", "p017", "p021", "p023", "p018", "p020", "p022", "p025"]),
        ("price_low", ["p025", "p022", "p023", "p018", "p020", "p017", "p024", "p019", "p021"]),
        ("price_high", ["p021", "p019", "p024", "p017", "p020", "p018", "p023", "p022", "p025"]),
        ("rating", ["p019", "p017", "p021", "p018", "p023", "p020", "p025", "p022", "p024"]),
    ],
)
def test_search_sort_combinations(client, sort_by: str, expected_ids: list[str]) -> None:
    response = client.post("/search", headers=AUTH_HEADERS, json={"category": "home", "sortBy": sort_by, "pageSize": 50})
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.SearchResponse, body)
    assert [product["id"] for product in body["products"]] == expected_ids


def test_search_paginates_with_page_token(client) -> None:
    first = client.post("/search", headers=AUTH_HEADERS, json={"category": "home", "sortBy": "price_low", "pageSize": 3})
    assert first.status_code == 200
    first_body = first.json()
    assert [product["id"] for product in first_body["products"]] == ["p025", "p022", "p023"]
    assert first_body["pageToken"] is not None

    second = client.post(
        "/search",
        headers=AUTH_HEADERS,
        json={"category": "home", "sortBy": "price_low", "pageSize": 3, "pageToken": first_body["pageToken"]},
    )
    assert second.status_code == 200
    second_body = second.json()
    assert_model(generated.SearchResponse, second_body)
    assert [product["id"] for product in second_body["products"]] == ["p018", "p020", "p017"]


def test_search_empty_result_case(client) -> None:
    response = client.post("/search", headers=AUTH_HEADERS, json={"query": "nonexistent", "category": "home"})
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.SearchResponse, body)
    assert body == {"products": [], "pageToken": None, "total": 0, "appliedFilters": {"query": "nonexistent", "category": "home", "sortBy": "relevance"}}


def test_search_malformed_page_token(client) -> None:
    response = client.post("/search", headers=AUTH_HEADERS, json={"pageToken": "not-a-token"})
    assert response.status_code == 400
    body = response.json()
    assert_model(generated.ApiError, body)
    assert body["error"] == "invalid_page_token"


def test_get_product_success(client) -> None:
    response = client.get("/products/p017", headers=AUTH_HEADERS)
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.Product, body)
    assert body["id"] == "p017"
    assert {"arc", "ceramic", "decor", "lamp", "lighting", "table"}.issubset(
        set(body["searchTokens"])
    )


def test_get_product_not_found(client) -> None:
    response = client.get("/products/p999", headers=AUTH_HEADERS)
    assert response.status_code == 404
    body = response.json()
    assert_model(generated.ApiError, body)
    assert body["error"] == "not_found"


def test_batch_products_success(client) -> None:
    response = client.post("/products/batch", headers=AUTH_HEADERS, json={"ids": ["p017", "p021", "p999"]})
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.ProductBatchResponse, body)
    assert [product["id"] for product in body["products"]] == ["p017", "p021"]
    assert body["missingIds"] == ["p999"]


def test_batch_products_too_many_ids(client) -> None:
    response = client.post("/products/batch", headers=AUTH_HEADERS, json={"ids": [f"p{i:03d}" for i in range(21)]})
    assert response.status_code == 400
    assert_model(generated.ApiError, response.json())
    assert response.json()["error"] == "too_many_ids"


def test_recommendations_success(client) -> None:
    response = client.get("/recommendations/u_001", headers=AUTH_HEADERS)
    assert response.status_code == 200
    assert_model(generated.RecommendationsResponse, response.json())
    assert response.json()["fallbackUsed"] is False


def test_visual_search_success(client) -> None:
    response = client.post(
        "/visual-search",
        headers=AUTH_HEADERS,
        files={"image": ("shoe.jpg", b"fake image", "image/jpeg")},
        data={"mlKitLabels": "shoe"},
    )
    assert response.status_code == 200
    assert_model(generated.VisualSearchResponse, response.json())
    assert response.json()["fallbackMode"] is True


def test_explain_product_success(client, contract) -> None:
    payload = contract["paths"]["/explain-product"]["post"]["requestBody"]["content"]["application/json"]["examples"]["request"]["value"]
    response = client.post("/explain-product", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    assert_model(generated.ExplainProductResponse, response.json())
    assert response.json()["provider"] == "template"


def test_events_success(client, contract) -> None:
    payload = contract["paths"]["/events"]["post"]["requestBody"]["content"]["application/json"]["examples"]["request"]["value"]
    response = client.post("/events", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.EventResponse, body)
    assert body["accepted"] is True
    assert body["eventId"].startswith("e_")


def test_cart_validate_success(client, contract) -> None:
    payload = contract["paths"]["/cart/validate"]["post"]["requestBody"]["content"]["application/json"]["examples"]["request"]["value"]
    response = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    assert_model(generated.CartValidateResponse, response.json())
    assert response.json()["valid"] is True


def test_cart_validate_reports_price_drift(client) -> None:
    payload = {"items": [{"productId": "p017", "variantId": "clay-white", "quantity": 1, "priceSnapshot": 58.0}]}
    response = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    body = response.json()
    assert_model(generated.CartValidateResponse, body)
    assert body["valid"] is False
    assert body["changes"] == [
        {
            "productId": "p017",
            "variantId": "clay-white",
            "reason": "price_changed",
            "oldPrice": 58.0,
            "newPrice": 64.0,
            "oldQuantity": None,
            "newQuantity": None,
        }
    ]


def test_cart_validate_reports_unavailable_product(client) -> None:
    payload = {"items": [{"productId": "p999", "quantity": 1, "priceSnapshot": 12.0}]}
    response = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["valid"] is False
    assert body["changes"][0]["reason"] == "unavailable"
    assert body["changes"][0]["newQuantity"] == 0


def test_cart_validate_reports_stock_changes(client) -> None:
    payload = {
        "items": [
            {"productId": "p020", "quantity": 1, "priceSnapshot": 48.0},
            {"productId": "p017", "quantity": 20, "priceSnapshot": 64.0},
        ]
    }
    response = client.post("/cart/validate", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["valid"] is False
    assert [change["reason"] for change in body["changes"]] == ["out_of_stock", "quantity_reduced"]
    assert body["changes"][0]["newQuantity"] == 0
    assert body["changes"][1]["oldQuantity"] == 20
    assert body["changes"][1]["newQuantity"] == 18


def test_create_payment_intent_success(client, contract) -> None:
    payload = contract["paths"]["/create-payment-intent"]["post"]["requestBody"]["content"]["application/json"]["examples"]["request"]["value"]
    response = client.post("/create-payment-intent", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    assert_model(generated.CreatePaymentIntentResponse, response.json())
    assert response.json()["clientSecret"] == "pi_test_secret_abc"


def test_confirm_order_success(client, contract) -> None:
    payload = contract["paths"]["/orders/confirm"]["post"]["requestBody"]["content"]["application/json"]["examples"]["request"]["value"]
    response = client.post("/orders/confirm", headers=AUTH_HEADERS, json=payload)
    assert response.status_code == 200
    assert_model(generated.ConfirmOrderResponse, response.json())
    assert response.json()["status"] == "confirmed"


def test_get_orders_success(client) -> None:
    response = client.get("/orders/u_001", headers=AUTH_HEADERS)
    assert response.status_code == 200
    assert_model(generated.OrdersResponse, response.json())
    assert response.json()["count"] == 1


def test_get_orders_forbidden_for_other_uid(client) -> None:
    response = client.get("/orders/u_002", headers=AUTH_HEADERS)
    assert response.status_code == 403
    assert_model(generated.ApiError, response.json())
    assert response.json()["error"] == "forbidden"
