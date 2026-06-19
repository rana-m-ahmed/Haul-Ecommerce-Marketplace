from __future__ import annotations

from time import perf_counter

from backend.app.schemas import generated
from backend.app.services.event_repository import LocalEventRepository
from backend.app.tests.conftest import AUTH_HEADERS


def _headers(uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer test-token:{uid}"}


def test_visual_search_disabled_gemini_falls_back_and_cache_is_fast(client) -> None:
    request = {
        "headers": AUTH_HEADERS,
        "files": {"image": ("shoe.jpg", b"identical-image-bytes", "image/jpeg")},
        "data": {"mlKitLabels": "shoe,white,athletic"},
    }
    first = client.post("/visual-search", **request)
    started = perf_counter()
    second = client.post("/visual-search", **request)
    elapsed_ms = (perf_counter() - started) * 1000

    assert first.status_code == second.status_code == 200
    generated.VisualSearchResponse.model_validate(second.json())
    assert second.json()["fallbackMode"] is True
    assert second.json()["detectedAttributes"]["primaryCategory"] == "fitness"
    assert second.json()["products"]
    assert elapsed_ms < 200


def test_explanation_disabled_gemini_returns_template_then_cache(client) -> None:
    payload = {"uid": "u_001", "productId": "p017"}
    first = client.post("/explain-product", headers=AUTH_HEADERS, json=payload)
    second = client.post("/explain-product", headers=AUTH_HEADERS, json=payload)

    assert first.status_code == second.status_code == 200
    generated.ExplainProductResponse.model_validate(first.json())
    assert first.json()["provider"] == "template"
    assert first.json()["cached"] is False
    assert first.json()["explanationText"].startswith("Because you showed interest in ")
    assert second.json()["cached"] is True


def test_explanation_hidden_without_preference_signal(client) -> None:
    LocalEventRepository._users["guest"] = {"isGuest": True, "preferences": []}
    response = client.post(
        "/explain-product",
        headers=_headers("guest"),
        json={"uid": "guest", "productId": "p017"},
    )
    assert response.status_code == 404
    assert response.json()["error"] == "preference_signal_missing"


def test_two_event_histories_produce_different_recommendations(client) -> None:
    LocalEventRepository._events["home_user"] = [
        {"eventType": "purchase", "productId": "p017", "category": "home", "metadata": {}},
        {"eventType": "wishlist", "productId": "p021", "category": "home", "metadata": {}},
    ]
    LocalEventRepository._events["fitness_user"] = [
        {"eventType": "purchase", "productId": "p034", "category": "fitness", "metadata": {}},
        {"eventType": "add_to_cart", "productId": "p035", "category": "fitness", "metadata": {}},
    ]

    home = client.get("/recommendations/home_user", headers=_headers("home_user"))
    fitness = client.get("/recommendations/fitness_user", headers=_headers("fitness_user"))

    assert home.status_code == fitness.status_code == 200
    generated.RecommendationsResponse.model_validate(home.json())
    generated.RecommendationsResponse.model_validate(fitness.json())
    home_ids = [product["id"] for product in home.json()["products"]]
    fitness_ids = [product["id"] for product in fitness.json()["products"]]
    assert home_ids != fitness_ids
    assert home.json()["products"][0]["category"] == "home"
    assert fitness.json()["products"][0]["category"] == "fitness"


def test_recommendations_cold_start_uses_trending(client) -> None:
    response = client.get("/recommendations/cold_user", headers=_headers("cold_user"))
    assert response.status_code == 200
    assert response.json()["fallbackUsed"] is True
    assert response.json()["reason"] == "trending"
    assert response.json()["products"]
