from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any


class CatalogRunStore:
    """Small durable checkpoint store; every write commits immediately."""

    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self.connection = sqlite3.connect(path, timeout=10.0)
        self.connection.row_factory = sqlite3.Row
        self.connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS slots (
                slot_id TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                rejection TEXT,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS candidates (
                slot_id TEXT NOT NULL,
                photo_id TEXT NOT NULL,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (slot_id, photo_id)
            );
            CREATE TABLE IF NOT EXISTS searches (
                query TEXT PRIMARY KEY,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()

    def set_meta(self, key: str, value: Any) -> None:
        encoded = json.dumps(value, sort_keys=True)
        self.connection.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, encoded),
        )
        self.connection.commit()

    def get_meta(self, key: str, default: Any = None) -> Any:
        row = self.connection.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return json.loads(row["value"]) if row else default

    def increment(self, key: str) -> int:
        value = int(self.get_meta(key, 0)) + 1
        self.set_meta(key, value)
        return value

    def set_slot(self, slot_id: str, status: str, rejection: str | None = None) -> None:
        self.connection.execute(
            """INSERT INTO slots(slot_id, status, rejection) VALUES (?, ?, ?)
            ON CONFLICT(slot_id) DO UPDATE SET status=excluded.status, rejection=excluded.rejection,
            updated_at=CURRENT_TIMESTAMP""",
            (slot_id, status, rejection),
        )
        self.connection.commit()

    def slots(self) -> list[dict[str, Any]]:
        return [dict(row) for row in self.connection.execute("SELECT * FROM slots ORDER BY slot_id")]

    def save_candidate(self, slot_id: str, photo_id: str, payload: dict[str, Any]) -> None:
        self.connection.execute(
            """INSERT INTO candidates(slot_id, photo_id, payload) VALUES (?, ?, ?)
            ON CONFLICT(slot_id, photo_id) DO UPDATE SET payload=excluded.payload, updated_at=CURRENT_TIMESTAMP""",
            (slot_id, photo_id, json.dumps(payload, sort_keys=True)),
        )
        self.connection.commit()

    def candidates(self, slot_id: str) -> list[dict[str, Any]]:
        rows = self.connection.execute(
            "SELECT payload FROM candidates WHERE slot_id=? ORDER BY updated_at", (slot_id,)
        )
        return [json.loads(row["payload"]) for row in rows]

    def provider_response_counts(self) -> dict[str, int]:
        payloads = [json.loads(row["payload"]) for row in self.connection.execute("SELECT payload FROM candidates")]
        return {
            "groq": sum(1 for item in payloads if item.get("groqReview")),
            "gemini": sum(1 for item in payloads if item.get("geminiReview")),
        }

    def save_search(self, query: str, payload: list[dict[str, Any]]) -> None:
        self.connection.execute(
            """INSERT INTO searches(query, payload) VALUES (?, ?)
            ON CONFLICT(query) DO UPDATE SET payload=excluded.payload, updated_at=CURRENT_TIMESTAMP""",
            (query, json.dumps(payload, sort_keys=True)),
        )
        self.connection.commit()

    def search(self, query: str) -> list[dict[str, Any]] | None:
        row = self.connection.execute("SELECT payload FROM searches WHERE query=?", (query,)).fetchone()
        return json.loads(row["payload"]) if row else None

    def event(self, level: str, message: str) -> None:
        self.connection.execute("INSERT INTO events(level, message) VALUES (?, ?)", (level, message))
        self.connection.commit()

    def summary(self) -> dict[str, Any]:
        slot_rows = self.slots()
        counts: dict[str, int] = {}
        for row in slot_rows:
            counts[row["status"]] = counts.get(row["status"], 0) + 1
        return {
            "status": self.get_meta("status", "new"),
            "runId": self.get_meta("run_id"),
            "startedAt": self.get_meta("started_at"),
            "updatedAt": self.get_meta("updated_at"),
            "fingerprint": self.get_meta("fingerprint"),
            "requests": {
                "unsplash": self.get_meta("unsplash_requests", 0),
                "groq": self.get_meta("groq_requests", 0),
                "gemini": self.get_meta("gemini_requests", 0),
            },
            "unsplashQuota": {
                "remaining": self.get_meta("unsplash_remaining"),
                "reset": self.get_meta("unsplash_reset"),
            },
            "slots": counts,
            "rejections": [row for row in slot_rows if row.get("rejection")],
        }
