from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_event_service
from backend.app.core.firebase import AuthenticatedUser, require_firebase_user
from backend.app.schemas.generated import EventRequest, EventResponse
from backend.app.services.event_service import EventService


router = APIRouter(tags=["Events"])


@router.post("/events", response_model=EventResponse)
def create_event(
    payload: EventRequest,
    user: AuthenticatedUser = Depends(require_firebase_user),
    service: EventService = Depends(get_event_service),
) -> dict:
    return service.create_event(user.uid, payload.model_dump())
