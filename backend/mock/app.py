from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


CONTRACT_PATH = Path(__file__).resolve().parents[2] / "progress" / "01_API_CONTRACT.yaml"

app = FastAPI(title="Hual Mock API", version="0.1.0")


@lru_cache
def contract() -> dict[str, Any]:
    with CONTRACT_PATH.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def example_payload(path: str, method: str, example: str = "success") -> JSONResponse:
    operation = contract()["paths"][path][method]
    responses = operation["responses"]

    for status_code, response in responses.items():
        examples = (
            response.get("content", {})
            .get("application/json", {})
            .get("examples", {})
        )
        if example in examples:
            return JSONResponse(status_code=int(status_code), content=examples[example]["value"])

    for status_code, response in responses.items():
        examples = (
            response.get("content", {})
            .get("application/json", {})
            .get("examples", {})
        )
        if examples:
            first = next(iter(examples.values()))
            return JSONResponse(status_code=int(status_code), content=first["value"])

    return JSONResponse(status_code=500, content={"error": "missing_example", "message": f"No examples for {method.upper()} {path}"})


@app.get("/health")
def get_health(example: str = "success") -> JSONResponse:
    return example_payload("/health", "get", example)


@app.post("/search")
async def search_products(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/search", "post", example)


@app.get("/products/{product_id}")
def get_product(product_id: str, example: str = "success") -> JSONResponse:
    return example_payload("/products/{id}", "get", example)


@app.post("/products/batch")
async def batch_products(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/products/batch", "post", example)


@app.get("/recommendations/{uid}")
def get_recommendations(uid: str, example: str = "success") -> JSONResponse:
    return example_payload("/recommendations/{uid}", "get", example)


@app.post("/visual-search")
async def visual_search(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/visual-search", "post", example)


@app.post("/explain-product")
async def explain_product(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/explain-product", "post", example)


@app.post("/events")
async def create_event(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/events", "post", example)


@app.post("/cart/validate")
async def validate_cart(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/cart/validate", "post", example)


@app.post("/create-payment-intent")
async def create_payment_intent(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/create-payment-intent", "post", example)


@app.post("/orders/confirm")
async def confirm_order(request: Request, example: str = "success") -> JSONResponse:
    await request.body()
    return example_payload("/orders/confirm", "post", example)


@app.get("/orders/{uid}")
def get_orders(uid: str, example: str = "success") -> JSONResponse:
    return example_payload("/orders/{uid}", "get", example)
