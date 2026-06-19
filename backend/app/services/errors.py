from dataclasses import dataclass


@dataclass(frozen=True)
class ServiceError(Exception):
    status_code: int
    error: str
    message: str

    def payload(self) -> dict[str, str]:
        return {"error": self.error, "message": self.message}
