from backend.app.services.event_repository import EventRepository


class EventService:
    def __init__(self, repository: EventRepository) -> None:
        self.repository = repository

    def create_event(self, uid: str, request: dict) -> dict:
        event_id = self.repository.create_event(uid, request)
        self.repository.delete_cache("recommendations", uid)
        return {"accepted": True, "eventId": event_id}
