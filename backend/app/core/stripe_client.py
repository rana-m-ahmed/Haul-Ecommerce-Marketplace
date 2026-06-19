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
