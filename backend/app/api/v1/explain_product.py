from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_ai_service
from backend.app.core.firebase import AuthenticatedUser, require_firebase_user
from backend.app.schemas.generated import ExplainProductRequest, ExplainProductResponse
from backend.app.services.ai_service import AiService


router = APIRouter(tags=["AI"])


@router.post("/explain-product", response_model=ExplainProductResponse)
async def explain_product(
    payload: ExplainProductRequest,
    user: AuthenticatedUser = Depends(require_firebase_user),
    service: AiService = Depends(get_ai_service),
) -> dict:
    if payload.uid != user.uid:
        from backend.app.services.errors import ServiceError

        raise ServiceError(403, "forbidden", "Cannot explain products for a different user")
    return await service.explain_product(payload.model_dump())
