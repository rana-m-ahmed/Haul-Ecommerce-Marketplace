from __future__ import annotations

import json
from dataclasses import dataclass

import firebase_admin
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, credentials

from backend.app.core.config import Settings, get_settings


bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    uid: str
    email: str | None = None
    claims: dict | None = None


def initialize_firebase(settings: Settings) -> firebase_admin.App:
    if firebase_admin._apps:
        return firebase_admin.get_app()

    if settings.firebase_service_account_json:
        service_account = json.loads(settings.firebase_service_account_json)
        cred = credentials.Certificate(service_account)
        return firebase_admin.initialize_app(cred, {"projectId": settings.firebase_project_id})

    return firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})


def verify_id_token(token: str, settings: Settings) -> AuthenticatedUser:
    if settings.auth_allow_test_tokens and token.startswith("test-token"):
        uid = token.partition(":")[2] or "u_001"
        return AuthenticatedUser(uid=uid, email="test@example.com", claims={"test": True})

    initialize_firebase(settings)
    decoded = auth.verify_id_token(token)
    return AuthenticatedUser(uid=decoded["uid"], email=decoded.get("email"), claims=decoded)


def require_firebase_user(
    credentials_value: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    # X-API-Key is intentionally ignored for authorization. If present, it is only
    # a non-secret client identifier for analytics/routing; Firebase ID tokens are
    # the sole security boundary for user-authenticated routes.
    _ = x_api_key
    if not credentials_value:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "missing_auth", "message": "Missing Firebase bearer token"},
        )
    try:
        return verify_id_token(credentials_value.credentials, settings)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "invalid_auth", "message": "Firebase ID token could not be verified"},
        ) from exc
