from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_health_service
from backend.app.schemas.generated import HealthResponse
from backend.app.services.health_service import HealthService


router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
def get_health(service: HealthService = Depends(get_health_service)) -> dict:
    return service.health()
