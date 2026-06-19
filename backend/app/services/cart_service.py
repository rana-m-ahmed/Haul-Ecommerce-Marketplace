from decimal import Decimal

from backend.app.services.catalog_repository import CatalogRepository


class CartService:
    def __init__(self, repository: CatalogRepository) -> None:
        self.repository = repository

    def validate_cart(self, request: dict) -> dict:
        changes = []
        for item in request.get("items") or []:
            product_id = item["productId"]
            variant_id = item.get("variantId")
            quantity = item["quantity"]
            product = self.repository.get_product(product_id)

            if product is None:
                changes.append(
                    {
                        "productId": product_id,
                        "variantId": variant_id,
                        "reason": "unavailable",
                        "oldPrice": item.get("priceSnapshot"),
                        "newPrice": None,
                        "oldQuantity": quantity,
                        "newQuantity": 0,
                    }
                )
                continue

            current_price = self._effective_price(product)
            snapshot_price = self._money(item["priceSnapshot"])
            inventory = int(product.get("inventory") or 0)

            if snapshot_price != current_price:
                changes.append(
                    {
                        "productId": product_id,
                        "variantId": variant_id,
                        "reason": "price_changed",
                        "oldPrice": float(snapshot_price),
                        "newPrice": float(current_price),
                        "oldQuantity": None,
                        "newQuantity": None,
                    }
                )

            if inventory <= 0:
                changes.append(
                    {
                        "productId": product_id,
                        "variantId": variant_id,
                        "reason": "out_of_stock",
                        "oldPrice": None,
                        "newPrice": None,
                        "oldQuantity": quantity,
                        "newQuantity": 0,
                    }
                )
            elif quantity > inventory:
                changes.append(
                    {
                        "productId": product_id,
                        "variantId": variant_id,
                        "reason": "quantity_reduced",
                        "oldPrice": None,
                        "newPrice": None,
                        "oldQuantity": quantity,
                        "newQuantity": inventory,
                    }
                )

        return {"valid": not changes, "changes": changes}

    def _effective_price(self, product: dict) -> Decimal:
        price = product["salePrice"] if product.get("salePrice") is not None else product["price"]
        return self._money(price)

    def _money(self, value: float | int | Decimal) -> Decimal:
        return Decimal(str(value)).quantize(Decimal("0.01"))
