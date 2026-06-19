from datetime import UTC, datetime

from backend.app.core.config import Settings


class HealthService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def health(self) -> dict:
        return {
            "status": "ok",
            "version": self.settings.version,
            "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        }
