from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_cart_service
from backend.app.core.firebase import require_firebase_user
from backend.app.schemas.generated import CartValidateRequest, CartValidateResponse
from backend.app.services.cart_service import CartService


router = APIRouter(tags=["Cart"], dependencies=[Depends(require_firebase_user)])


@router.post("/cart/validate", response_model=CartValidateResponse)
def validate_cart(
    payload: CartValidateRequest,
    service: CartService = Depends(get_cart_service),
) -> dict:
    return service.validate_cart(payload.model_dump())
