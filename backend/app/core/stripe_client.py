from __future__ import annotations

import stripe

from backend.app.core.config import Settings


class StripeClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        if settings.stripe_secret_key:
            stripe.api_key = settings.stripe_secret_key

    def is_configured(self) -> bool:
        return bool(self.settings.stripe_secret_key)

    def create_payment_intent(
        self,
        *,
        amount: int,
        currency: str,
        uid: str,
        shipping_address: str,
    ) -> dict:
        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency=currency,
            automatic_payment_methods={"enabled": True},
            metadata={"uid": uid, "shippingAddress": shipping_address},
        )
        return dict(intent)

    def retrieve_payment_intent(self, payment_intent_id: str) -> dict:
        return dict(stripe.PaymentIntent.retrieve(payment_intent_id))
