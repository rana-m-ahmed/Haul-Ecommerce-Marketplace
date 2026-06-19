from functools import lru_cache

from backend.app.core.config import get_settings
from backend.app.services.catalog_repository import catalog_repository
from backend.app.services.ai_service import AiService
from backend.app.services.cart_service import CartService
from backend.app.services.catalog_service import CatalogService
from backend.app.services.checkout_service import CheckoutService
from backend.app.services.event_repository import event_repository
from backend.app.services.event_service import EventService
from backend.app.services.health_service import HealthService
from backend.app.core.gemini_client import GeminiClient


@lru_cache
def get_catalog_service() -> CatalogService:
    return CatalogService(catalog_repository(get_settings()))


@lru_cache
def get_ai_service() -> AiService:
    settings = get_settings()
    return AiService(
        catalog_repository(settings),
        event_repository(settings),
        GeminiClient(settings),
        cache_ttl_seconds=settings.ai_cache_ttl_seconds,
    )


@lru_cache
def get_event_service() -> EventService:
    return EventService(event_repository(get_settings()))


@lru_cache
def get_cart_service() -> CartService:
    return CartService(catalog_repository(get_settings()))


@lru_cache
def get_checkout_service() -> CheckoutService:
    return CheckoutService()


def get_health_service() -> HealthService:
    return HealthService(get_settings())
