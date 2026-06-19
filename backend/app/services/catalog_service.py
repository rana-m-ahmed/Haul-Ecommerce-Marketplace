from __future__ import annotations

from datetime import datetime

from backend.app.services.catalog_repository import CatalogRepository
from backend.app.services.errors import ServiceError
from backend.app.services.pagination import decode_page_token, encode_page_token


class CatalogService:
    def __init__(self, repository: CatalogRepository) -> None:
        self.repository = repository

    def search(self, request: dict) -> dict:
        products = self.repository.list_products()
        query = (request.get("query") or "").strip().lower()
        category = request.get("category")
        colors = set(request.get("colors") or [])
        materials = set(request.get("materials") or [])
        tags = set(request.get("tags") or [])
        min_price = request.get("minPrice")
        max_price = request.get("maxPrice")
        sort_by = request.get("sortBy") or "relevance"
        page_size = request.get("pageSize") or 12
        offset = decode_page_token(request.get("pageToken"))

        if min_price is not None and max_price is not None and min_price > max_price:
            return self._response([], None, 0, request)

        filtered = [
            product
            for product in products
            if self._matches(product, query, category, colors, materials, tags, min_price, max_price)
        ]
        filtered = self._sort(filtered, sort_by, query)

        page = filtered[offset : offset + page_size]
        next_offset = offset + page_size
        page_token = encode_page_token(next_offset) if next_offset < len(filtered) else None
        return self._response(page, page_token, len(filtered), request)

    def get_product(self, product_id: str) -> dict:
        product = self.repository.get_product(product_id)
        if product is None:
            raise ServiceError(404, "not_found", "No product with that id")
        return product

    def batch_products(self, request: dict) -> dict:
        ids = request.get("ids") or []
        if len(ids) > 20:
            raise ServiceError(400, "too_many_ids", "ids must contain 20 or fewer product ids")
        products = []
        missing = []
        for product_id in ids:
            product = self.repository.get_product(product_id)
            if product is None:
                missing.append(product_id)
            else:
                products.append(product)
        return {"products": products, "missingIds": missing}

    def _matches(
        self,
        product: dict,
        query: str,
        category: str | None,
        colors: set[str],
        materials: set[str],
        tags: set[str],
        min_price: float | None,
        max_price: float | None,
    ) -> bool:
        effective_price = product["salePrice"] if product.get("salePrice") is not None else product["price"]
        if category and product["category"] != category:
            return False
        if colors and not colors.intersection(product.get("colors", [])):
            return False
        if materials and not materials.intersection(product.get("materials", [])):
            return False
        if tags and not tags.intersection(product.get("tags", [])):
            return False
        if min_price is not None and effective_price < min_price:
            return False
        if max_price is not None and effective_price > max_price:
            return False
        if query:
            query_tokens = query.split()
            product_tokens = set(product.get("searchTokens", []))
            return all(token in product_tokens for token in query_tokens)
        return True

    def _sort(self, products: list[dict], sort_by: str, query: str) -> list[dict]:
        if sort_by == "newest":
            return sorted(products, key=lambda product: datetime.fromisoformat(product["createdAt"].replace("Z", "+00:00")), reverse=True)
        if sort_by == "price_low":
            return sorted(products, key=self._effective_price)
        if sort_by == "price_high":
            return sorted(products, key=self._effective_price, reverse=True)
        if sort_by == "rating":
            return sorted(products, key=lambda product: (product["rating"], product["reviewCount"]), reverse=True)
        if query:
            query_tokens = set(query.split())
            return sorted(
                products,
                key=lambda product: (len(query_tokens.intersection(product.get("searchTokens", []))), product["rating"]),
                reverse=True,
            )
        return products

    def _effective_price(self, product: dict) -> float:
        return product["salePrice"] if product.get("salePrice") is not None else product["price"]

    def _response(self, products: list[dict], page_token: str | None, total: int, request: dict) -> dict:
        applied = {
            key: value
            for key, value in {
                "query": request.get("query"),
                "category": request.get("category"),
                "colors": request.get("colors"),
                "materials": request.get("materials"),
                "tags": request.get("tags"),
                "minPrice": request.get("minPrice"),
                "maxPrice": request.get("maxPrice"),
                "sortBy": request.get("sortBy") or "relevance",
            }.items()
            if value not in (None, [], "")
        }
        return {"products": products, "pageToken": page_token, "total": total, "appliedFilters": applied}
