from __future__ import annotations

import json

from backend.app.core.stripe_client import StripeClient
from backend.app.services.checkout_repository import CheckoutRepository
from backend.app.services.errors import ServiceError


class CheckoutService:
    def __init__(
        self,
        repository: CheckoutRepository,
        stripe_client: StripeClient,
        currency: str = "usd",
    ) -> None:
        self.repository = repository
        self.stripe_client = stripe_client
        self.currency = currency.lower()

    def create_payment_intent(self, uid: str, request: dict) -> dict:
        _, amount = self.repository.price_cart(uid)
        shipping_address = request["shippingAddress"]
        intent = self.stripe_client.create_payment_intent(
            amount=amount,
            currency=self.currency,
            uid=uid,
            shipping_address=json.dumps(shipping_address, separators=(",", ":")),
        )
        client_secret = intent.get("client_secret")
        if not client_secret:
            raise ServiceError(502, "stripe_error", "Stripe did not return a client secret")
        return {"clientSecret": client_secret, "amount": amount, "currency": self.currency}

    def confirm_order(self, uid: str, request: dict) -> dict:
        payment_intent_id = request["paymentIntentId"]
        intent = self.stripe_client.retrieve_payment_intent(payment_intent_id)
        if intent.get("status") != "succeeded":
            raise ServiceError(402, "payment_not_succeeded", "PaymentIntent status was not succeeded")

        metadata = intent.get("metadata") or {}
        if metadata.get("uid") != uid:
            raise ServiceError(403, "payment_owner_mismatch", "PaymentIntent belongs to a different user")
        try:
            shipping_address = json.loads(metadata["shippingAddress"])
        except (KeyError, TypeError, json.JSONDecodeError) as exc:
            raise ServiceError(409, "payment_metadata_invalid", "PaymentIntent shipping metadata is invalid") from exc

        order = self.repository.confirm_order(
            uid=uid,
            payment_intent_id=payment_intent_id,
            paid_amount=int(intent["amount"]),
            currency=str(intent["currency"]).lower(),
            shipping_address=shipping_address,
        )
        return {
            "orderId": order["orderId"],
            "orderNumber": order["orderNumber"],
            "status": order["status"],
        }

    def get_orders(self, uid: str) -> dict:
        orders = self.repository.get_orders(uid)
        return {"orders": orders, "count": len(orders)}
