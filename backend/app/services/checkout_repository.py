from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Protocol

from backend.app.core.config import Settings
from backend.app.core.firebase import initialize_firebase
from backend.app.services.errors import ServiceError


class CheckoutRepository(Protocol):
    def price_cart(self, uid: str) -> tuple[list[dict], int]:
        ...

    def confirm_order(
        self,
        *,
        uid: str,
        payment_intent_id: str,
        paid_amount: int,
        currency: str,
        shipping_address: dict,
    ) -> dict:
        ...

    def get_orders(self, uid: str) -> list[dict]:
        ...


def _money(value: object) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _unit_price(product: dict) -> Decimal:
    value = product["salePrice"] if product.get("salePrice") is not None else product["price"]
    return _money(value)


def _minor_units(value: Decimal) -> int:
    return int((value * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


class FirestoreCheckoutRepository:
    def __init__(self, settings: Settings) -> None:
        if os.environ.get("FIRESTORE_EMULATOR_HOST"):
            from google.auth.credentials import AnonymousCredentials
            from google.cloud import firestore

            self.firestore = firestore
            self.client = firestore.Client(
                project=settings.firebase_project_id or "hual-local",
                credentials=AnonymousCredentials(),
            )
            return

        initialize_firebase(settings)
        from firebase_admin import firestore

        self.firestore = firestore
        self.client = firestore.client()

    def price_cart(self, uid: str) -> tuple[list[dict], int]:
        cart = list(self.client.collection("users").document(uid).collection("cart").stream())
        if not cart:
            raise ServiceError(400, "empty_cart", "Add at least one in-stock item before checkout")

        items: list[dict] = []
        total = Decimal("0.00")
        for cart_snapshot in cart:
            cart_item = cart_snapshot.to_dict()
            product_id = cart_item["productId"]
            product_snapshot = self.client.collection("products").document(product_id).get()
            if not product_snapshot.exists:
                raise ServiceError(400, "unavailable_product", f"Product {product_id} is unavailable")

            product = product_snapshot.to_dict()
            quantity = int(cart_item["quantity"])
            if int(product.get("inventory") or 0) < quantity:
                raise ServiceError(409, "cart_out_of_stock", "One or more cart items are no longer available")

            unit_price = _unit_price(product)
            subtotal = unit_price * quantity
            total += subtotal
            items.append(
                {
                    "productId": product_id,
                    "variantId": cart_item.get("variantId"),
                    "name": product["name"],
                    "quantity": quantity,
                    "unitPrice": float(unit_price),
                    "subtotal": float(subtotal),
                }
            )
        return items, _minor_units(total)

    def confirm_order(
        self,
        *,
        uid: str,
        payment_intent_id: str,
        paid_amount: int,
        currency: str,
        shipping_address: dict,
    ) -> dict:
        order_id = "o_" + hashlib.sha256(f"{uid}:{payment_intent_id}".encode()).hexdigest()[:24]
        user_ref = self.client.collection("users").document(uid)
        order_ref = user_ref.collection("orders").document(order_id)
        transaction = self.client.transaction()

        @self.firestore.transactional
        def apply(transaction):
            existing = order_ref.get(transaction=transaction)
            if existing.exists:
                return existing.to_dict() | {"orderId": existing.id}

            cart_snapshots = list(user_ref.collection("cart").stream(transaction=transaction))
            if not cart_snapshots:
                raise ServiceError(400, "empty_cart", "Add at least one in-stock item before checkout")

            product_rows: list[tuple[object, dict, dict]] = []
            items: list[dict] = []
            total = Decimal("0.00")
            for cart_snapshot in cart_snapshots:
                cart_item = cart_snapshot.to_dict()
                product_ref = self.client.collection("products").document(cart_item["productId"])
                product_snapshot = product_ref.get(transaction=transaction)
                if not product_snapshot.exists:
                    raise ServiceError(
                        409,
                        "inventory_changed",
                        "A cart product became unavailable before confirmation",
                    )

                product = product_snapshot.to_dict()
                quantity = int(cart_item["quantity"])
                inventory = int(product.get("inventory") or 0)
                if inventory < quantity:
                    raise ServiceError(
                        409,
                        "inventory_changed",
                        "Inventory changed before confirmation",
                    )

                unit_price = _unit_price(product)
                subtotal = unit_price * quantity
                total += subtotal
                items.append(
                    {
                        "productId": cart_item["productId"],
                        "variantId": cart_item.get("variantId"),
                        "name": product["name"],
                        "quantity": quantity,
                        "unitPrice": float(unit_price),
                        "subtotal": float(subtotal),
                    }
                )
                product_rows.append((product_ref, product, cart_item))

            if _minor_units(total) != paid_amount:
                raise ServiceError(
                    409,
                    "payment_amount_mismatch",
                    "The paid amount no longer matches current cart pricing",
                )

            now = datetime.now(timezone.utc)
            day = now.strftime("%Y%m%d")
            counter_ref = (
                self.client.collection("counters")
                .document("orderSequence")
                .collection("days")
                .document(day)
            )
            counter_snapshot = counter_ref.get(transaction=transaction)
            sequence = int(counter_snapshot.to_dict().get("count", 0)) + 1 if counter_snapshot.exists else 1
            order_number = f"HUL-{day}-{sequence:04d}"
            order = {
                "orderNumber": order_number,
                "items": items,
                "total": float(total),
                "currency": currency,
                "status": "confirmed",
                "shippingAddress": shipping_address,
                "paymentIntentId": payment_intent_id,
                "createdAt": now,
            }

            transaction.set(counter_ref, {"count": sequence})
            transaction.set(order_ref, order)
            for product_ref, product, cart_item in product_rows:
                transaction.update(
                    product_ref,
                    {"inventory": int(product["inventory"]) - int(cart_item["quantity"])},
                )
            for cart_snapshot in cart_snapshots:
                transaction.delete(cart_snapshot.reference)
            return order | {"orderId": order_id}

        return apply(transaction)

    def get_orders(self, uid: str) -> list[dict]:
        query = (
            self.client.collection("users")
            .document(uid)
            .collection("orders")
            .order_by("createdAt", direction=self.firestore.Query.DESCENDING)
        )
        return [snapshot.to_dict() | {"orderId": snapshot.id} for snapshot in query.stream()]


def checkout_repository(settings: Settings) -> CheckoutRepository:
    return FirestoreCheckoutRepository(settings)
