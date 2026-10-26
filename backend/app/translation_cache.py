"""Local translation cache.

Every text block handed to a provider is looked up here first, keyed by a
stable hash of (provider, target language, source text). A hit skips the
provider API call entirely, so repeated phrases -- page headers, boilerplate,
common sentences, or the same phrase appearing in a different PDF -- cost
nothing after the first translation.

The store is a plain SQLite file (stdlib only, no new dependencies) living
under backend/. Override the location with TRANSLATION_CACHE_PATH.
"""

from __future__ import annotations

import hashlib
import os
import sqlite3
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

DEFAULT_CACHE_PATH = Path(__file__).resolve().parent.parent / "translation_cache.db"

_lock = threading.Lock()
_connection: Optional[sqlite3.Connection] = None


@dataclass
class CacheStats:
    """Per-request cache accounting, returned to the client in the response."""

    hits: int = 0
    misses: int = 0
    provider_calls: int = 0

    @property
    def total(self) -> int:
        return self.hits + self.misses

    @property
    def hit_rate(self) -> float:
        return (self.hits / self.total) if self.total else 0.0

    def to_dict(self) -> dict:
        return {
            "hits": self.hits,
            "misses": self.misses,
            "provider_calls": self.provider_calls,
            "hit_rate": round(self.hit_rate, 4),
        }


def cache_key(provider: str, target_lang: str, text: str) -> str:
    """Stable key: same provider + target language + source text -> same key."""
    payload = f"{provider}\n{target_lang}\n{text}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _db_path() -> Path:
    override = os.environ.get("TRANSLATION_CACHE_PATH")
    return Path(override) if override else DEFAULT_CACHE_PATH


def _get_connection() -> sqlite3.Connection:
    global _connection
    if _connection is None:
        path = _db_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(path), check_same_thread=False)
        conn.execute(
            "CREATE TABLE IF NOT EXISTS translations ("
            "key TEXT PRIMARY KEY, value TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
        )
        conn.commit()
        _connection = conn
    return _connection


def get(key: str) -> Optional[str]:
    """Return the cached translation, or None on a miss."""
    with _lock:
        row = _get_connection().execute("SELECT value FROM translations WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None


def set(key: str, value: str) -> None:
    with _lock:
        conn = _get_connection()
        conn.execute(
            "INSERT OR REPLACE INTO translations (key, value) VALUES (?, ?)",
            (key, value),
        )
        conn.commit()


def clear() -> None:
    with _lock:
        conn = _get_connection()
        conn.execute("DELETE FROM translations")
        conn.commit()


def reset_connection() -> None:
    """Drop the cached connection (used by tests that switch cache paths)."""
    global _connection
    with _lock:
        if _connection is not None:
            _connection.close()
        _connection = None
