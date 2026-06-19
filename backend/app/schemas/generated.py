"""Generated from progress/01_API_CONTRACT.yaml. Do not edit by hand."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict


class ContractModel(BaseModel):
    model_config = ConfigDict(extra='forbid')

Category = Literal['fashion', 'electronics', 'home', 'skincare', 'fitness', 'accessories']

class ApiError(ContractModel):
    error: str
    message: str
    fallbackMode: bool | None = None

class Product(ContractModel):
    id: str
    name: str
    description: str
    price: float
    salePrice: float | None = None
    category: Category
    colors: list[str]
    materials: list[str]
    style: list[str]
    tags: list[str]
    searchTokens: list[str]
    imageUrls: list[str]
    rating: float
    reviewCount: int
    inventory: int
    isNew: bool
    isSale: bool
    createdAt: datetime

class ProductSummary(Product):
    pass

class Address(ContractModel):
    line1: str
    line2: str | None = None
    city: str
    region: str | None = None
    postalCode: str | None = None
    country: str

class CartItemInput(ContractModel):
    productId: str
    variantId: str | None = None
    quantity: int
    priceSnapshot: float

class CartChange(ContractModel):
    productId: str
    variantId: str | None = None
    reason: Literal['price_changed', 'out_of_stock', 'quantity_reduced', 'unavailable']
    oldPrice: float | None = None
    newPrice: float | None = None
    oldQuantity: int | None = None
    newQuantity: int | None = None

class OrderItem(ContractModel):
    productId: str
    variantId: str | None = None
    name: str
    quantity: int
    unitPrice: float
    subtotal: float

class Order(ContractModel):
    orderId: str
    orderNumber: str
    items: list[OrderItem]
    total: float
    currency: str
    status: Literal['confirmed', 'processing', 'shipped', 'delivered', 'canceled']
    shippingAddress: Address
    paymentIntentId: str
    createdAt: datetime

class HealthResponse(ContractModel):
    status: Literal['ok']
    version: str
    timestamp: datetime

class SearchRequest(ContractModel):
    query: str | None = None
    category: Category | None = None
    colors: list[str] = None
    materials: list[str] = None
    tags: list[str] = None
    minPrice: float | None = None
    maxPrice: float | None = None
    sortBy: Literal['relevance', 'newest', 'price_low', 'price_high', 'rating'] = None
    pageSize: int = None
    pageToken: str | None = None

class SearchResponse(ContractModel):
    products: list[ProductSummary]
    pageToken: str | None = None
    total: int
    appliedFilters: dict[str, Any]

class ProductBatchRequest(ContractModel):
    ids: list[str]

class ProductBatchResponse(ContractModel):
    products: list[Product]
    missingIds: list[str]

class RecommendationsResponse(ContractModel):
    products: list[ProductSummary]
    fallbackUsed: bool
    reason: str

class DetectedAttributes(ContractModel):
    primaryCategory: Category
    objectType: str | None = None
    colors: list[str]
    materials: list[str]
    style: str | None = None

class VisualSearchResponse(ContractModel):
    products: list[ProductSummary]
    detectedAttributes: DetectedAttributes
    matchScores: list[float]
    fallbackMode: bool
    queryTokens: list[str]

class ExplainProductRequest(ContractModel):
    uid: str
    productId: str

class ExplainProductResponse(ContractModel):
    explanationText: str
    provider: Literal['gemini', 'template']
    cached: bool

class EventRequest(ContractModel):
    eventType: Literal['purchase', 'add_to_cart', 'wishlist', 'long_dwell', 'product_view', 'visual_search_match_tap', 'text_search', 'category_tap', 'quick_bounce']
    productId: str | None = None
    category: Category | None = None
    sourceScreen: str
    metadata: dict[str, Any] = None

class EventResponse(ContractModel):
    accepted: bool
    eventId: str

class CartValidateRequest(ContractModel):
    items: list[CartItemInput]

class CartValidateResponse(ContractModel):
    valid: bool
    changes: list[CartChange]

class CreatePaymentIntentRequest(ContractModel):
    shippingAddress: Address

class CreatePaymentIntentResponse(ContractModel):
    clientSecret: str
    amount: int
    currency: str

class ConfirmOrderRequest(ContractModel):
    paymentIntentId: str

class ConfirmOrderResponse(ContractModel):
    orderId: str
    orderNumber: str
    status: Literal['confirmed']

class OrdersResponse(ContractModel):
    orders: list[Order]
    count: int
