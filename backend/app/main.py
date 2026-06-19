from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

from backend.app.api.v1.router import api_router
from backend.app.core.config import get_settings
from backend.app.services.errors import ServiceError


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version=settings.version)

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
        if isinstance(exc.detail, dict) and "error" in exc.detail and "message" in exc.detail:
            return JSONResponse(status_code=exc.status_code, content=exc.detail)
        return JSONResponse(status_code=exc.status_code, content={"error": "http_error", "message": str(exc.detail)})

    @app.exception_handler(ServiceError)
    async def service_error_handler(request: Request, exc: ServiceError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.payload())

    app.include_router(api_router)
    return app


app = create_app()
