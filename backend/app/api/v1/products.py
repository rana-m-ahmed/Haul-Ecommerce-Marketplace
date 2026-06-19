from fastapi import APIRouter, Depends

from backend.app.api.v1.dependencies import get_catalog_service
from backend.app.core.firebase import require_firebase_user
from backend.app.schemas.generated import Product, ProductBatchRequest, ProductBatchResponse
from backend.app.services.catalog_service import CatalogService


router = APIRouter(tags=["Catalog"], dependencies=[Depends(require_firebase_user)])


@router.get("/products/{id}", response_model=Product)
def get_product(id: str, service: CatalogService = Depends(get_catalog_service)) -> dict:
    return service.get_product(id)


@router.post("/products/batch", response_model=ProductBatchResponse)
def batch_products(
    payload: ProductBatchRequest,
    service: CatalogService = Depends(get_catalog_service),
) -> dict:
    return service.batch_products(payload.model_dump())
