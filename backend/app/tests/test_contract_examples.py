from __future__ import annotations

import pytest

from backend.app.schemas import generated


RESPONSE_MODELS = {
    ("/health", "get", "200"): generated.HealthResponse,
    ("/health", "get", "503"): generated.ApiError,
    ("/search", "post", "200"): generated.SearchResponse,
    ("/search", "post", "400"): generated.ApiError,
    ("/products/{id}", "get", "200"): generated.Product,
    ("/products/{id}", "get", "404"): generated.ApiError,
    ("/products/batch", "post", "200"): generated.ProductBatchResponse,
    ("/products/batch", "post", "400"): generated.ApiError,
    ("/recommendations/{uid}", "get", "200"): generated.RecommendationsResponse,
    ("/recommendations/{uid}", "get", "404"): generated.ApiError,
    ("/visual-search", "post", "200"): generated.VisualSearchResponse,
    ("/visual-search", "post", "422"): generated.ApiError,
    ("/explain-product", "post", "200"): generated.ExplainProductResponse,
    ("/explain-product", "post", "404"): generated.ApiError,
    ("/events", "post", "200"): generated.EventResponse,
    ("/events", "post", "400"): generated.ApiError,
    ("/cart/validate", "post", "200"): generated.CartValidateResponse,
    ("/cart/validate", "post", "409"): generated.ApiError,
    ("/create-payment-intent", "post", "200"): generated.CreatePaymentIntentResponse,
    ("/create-payment-intent", "post", "400"): generated.ApiError,
    ("/orders/confirm", "post", "200"): generated.ConfirmOrderResponse,
    ("/orders/confirm", "post", "402"): generated.ApiError,
    ("/orders/{uid}", "get", "200"): generated.OrdersResponse,
    ("/orders/{uid}", "get", "403"): generated.ApiError,
}


REQUEST_MODELS = {
    ("/search", "post"): generated.SearchRequest,
    ("/products/batch", "post"): generated.ProductBatchRequest,
    ("/explain-product", "post"): generated.ExplainProductRequest,
    ("/events", "post"): generated.EventRequest,
    ("/cart/validate", "post"): generated.CartValidateRequest,
    ("/create-payment-intent", "post"): generated.CreatePaymentIntentRequest,
    ("/orders/confirm", "post"): generated.ConfirmOrderRequest,
}


@pytest.mark.parametrize("path,method,status_code", RESPONSE_MODELS.keys())
def test_contract_response_examples_validate(contract, path: str, method: str, status_code: str) -> None:
    examples = (
        contract["paths"][path][method]["responses"][status_code]
        .get("content", {})
        .get("application/json", {})
        .get("examples", {})
    )
    assert examples, f"{method.upper()} {path} {status_code} has no examples"
    model = RESPONSE_MODELS[(path, method, status_code)]
    for name, example in examples.items():
        model.model_validate(example["value"]), name


@pytest.mark.parametrize("path,method", REQUEST_MODELS.keys())
def test_contract_request_examples_validate(contract, path: str, method: str) -> None:
    examples = (
        contract["paths"][path][method]
        .get("requestBody", {})
        .get("content", {})
        .get("application/json", {})
        .get("examples", {})
    )
    assert examples, f"{method.upper()} {path} has no request examples"
    model = REQUEST_MODELS[(path, method)]
    for name, example in examples.items():
        model.model_validate(example["value"]), name
