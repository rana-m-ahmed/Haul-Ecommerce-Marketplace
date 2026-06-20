from fastapi import APIRouter, Depends, HTTPException, status

from backend.app.api.v1.dependencies import get_checkout_service
from backend.app.core.firebase import AuthenticatedUser, require_firebase_user
from backend.app.schemas.generated import ConfirmOrderRequest, ConfirmOrderResponse, OrdersResponse
from backend.app.services.checkout_service import CheckoutService
from backend.app.services.contract_examples import response_example


router = APIRouter(tags=["Checkout"])


@router.post(
    "/orders/confirm",
    response_model=ConfirmOrderResponse,
)
def confirm_order(
    payload: ConfirmOrderRequest,
    user: AuthenticatedUser = Depends(require_firebase_user),
    service: CheckoutService = Depends(get_checkout_service),
) -> dict:
    return service.confirm_order(user.uid, payload.model_dump())


@router.get("/orders/{uid}", response_model=OrdersResponse)
def get_orders(
    uid: str,
    user: AuthenticatedUser = Depends(require_firebase_user),
    service: CheckoutService = Depends(get_checkout_service),
) -> dict:
    if uid != user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=response_example("/orders/{uid}", "get", "failure"),
        )
    return service.get_orders(uid)
