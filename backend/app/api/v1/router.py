from fastapi import APIRouter

from backend.app.api.v1 import (
    cart,
    events,
    explain_product,
    health,
    orders,
    payments,
    products,
    recommendations,
    search,
    visual_search,
)


api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(search.router)
api_router.include_router(products.router)
api_router.include_router(recommendations.router)
api_router.include_router(visual_search.router)
api_router.include_router(explain_product.router)
api_router.include_router(events.router)
api_router.include_router(cart.router)
api_router.include_router(payments.router)
api_router.include_router(orders.router)
