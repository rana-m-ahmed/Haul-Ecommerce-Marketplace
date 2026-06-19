from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_checkout_service
from backend.app.core.firebase import require_firebase_user
from backend.app.schemas.generated import CreatePaymentIntentRequest, CreatePaymentIntentResponse
from backend.app.services.checkout_service import CheckoutService


router = APIRouter(tags=["Checkout"], dependencies=[Depends(require_firebase_user)])


@router.post("/create-payment-intent", response_model=CreatePaymentIntentResponse)
def create_payment_intent(
    payload: CreatePaymentIntentRequest,
    service: CheckoutService = Depends(get_checkout_service),
) -> dict:
    return service.create_payment_intent(payload.model_dump())
