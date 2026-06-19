from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_ai_service
from backend.app.core.firebase import AuthenticatedUser, require_firebase_user
from backend.app.schemas.generated import RecommendationsResponse
from backend.app.services.ai_service import AiService


router = APIRouter(tags=["AI"])


@router.get("/recommendations/{uid}", response_model=RecommendationsResponse)
def get_recommendations(
    uid: str,
    user: AuthenticatedUser = Depends(require_firebase_user),
    service: AiService = Depends(get_ai_service),
) -> dict:
    if uid != user.uid:
        from backend.app.services.errors import ServiceError

        raise ServiceError(403, "forbidden", "Cannot read recommendations for a different user")
    return service.recommendations(uid)
