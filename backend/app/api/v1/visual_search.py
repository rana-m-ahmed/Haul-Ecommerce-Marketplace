from fastapi import APIRouter, Depends, File, Form, UploadFile

from backend.app.api.v1.dependencies import get_ai_service
from backend.app.core.firebase import require_firebase_user
from backend.app.schemas.generated import VisualSearchResponse
from backend.app.services.ai_service import AiService


router = APIRouter(tags=["AI"], dependencies=[Depends(require_firebase_user)])


@router.post("/visual-search", response_model=VisualSearchResponse)
async def visual_search(
    image: UploadFile = File(...),
    mlKitLabels: list[str] | None = Form(default=None),
    service: AiService = Depends(get_ai_service),
) -> dict:
    content_type = image.content_type or ""
    image_bytes = await image.read()
    if content_type not in {"image/jpeg", "image/png", "image/heic", "image/heif"} or len(image_bytes) > 8 * 1024 * 1024:
        from backend.app.services.errors import ServiceError

        raise ServiceError(422, "unsupported_image", "Upload a JPG, PNG, or HEIC image under 8 MB")
    labels = []
    for value in mlKitLabels or []:
        labels.extend(part.strip() for part in value.split(",") if part.strip())
    return await service.visual_search(image_bytes, content_type, labels)
