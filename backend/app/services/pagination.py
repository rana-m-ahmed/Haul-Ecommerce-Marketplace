from __future__ import annotations

import base64
import json

from backend.app.services.errors import ServiceError


def encode_page_token(offset: int) -> str | None:
    if offset <= 0:
        return None
    raw = json.dumps({"offset": offset}, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_page_token(token: str | None) -> int:
    if token is None:
        return 0
    try:
        padded = token + ("=" * (-len(token) % 4))
        payload = json.loads(base64.urlsafe_b64decode(padded.encode("ascii")))
        offset = payload["offset"]
    except Exception as exc:
        raise ServiceError(400, "invalid_page_token", "pageToken could not be decoded") from exc
    if not isinstance(offset, int) or offset < 0:
        raise ServiceError(400, "invalid_page_token", "pageToken could not be decoded")
    return offset
