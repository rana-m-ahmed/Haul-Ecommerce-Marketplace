from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_catalog_service
from backend.app.core.firebase import AuthenticatedUser, require_firebase_user
from backend.app.schemas.generated import SearchRequest, SearchResponse
from backend.app.services.catalog_service import CatalogService


router = APIRouter(tags=["Catalog"], dependencies=[Depends(require_firebase_user)])


@router.post("/search", response_model=SearchResponse)
def search_products(
    payload: SearchRequest,
    service: CatalogService = Depends(get_catalog_service),
) -> dict:
    return service.search(payload.model_dump())
