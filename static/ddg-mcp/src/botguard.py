"""Bot-Guard: UA-Rotation, Backoff, lokales Disk-Cache.

Schützt gegen Web-Server:
- Pro-Request zufälliger User-Agent aus Pool (verringert Bot-erkennung)
- Exponenzielle Backoff bei HTTP 403/429/503 (Rate-Limit)
- Disk-Cache unter ~/.cache/ddg-mcp (verringert Request-Last)
"""

from __future__ import annotations

import hashlib
import os
import random
import time
from pathlib import Path

_UA_POOL: list[str] = [
    # Kurze, realistische UA — kein „bot"-string
    "Mozilla/5.0 (X11; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0",
    # Chrome-Fallback (selten, für Engines, die UA-Checken)
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
]

_CACHE_DIR = Path(os.path.expanduser("~/.cache/ddg-mcp"))
_CACHE_TTL_S = 300  # 5 Minuten
_MAX_CACHE_FILES = 500


def _ensure_cache_dir() -> Path:
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    return _CACHE_DIR


def _cache_key(url: str) -> str:
    return hashlib.sha256(url.encode()).hexdigest()


def _cache_path(url: str) -> Path:
    return _CACHE_DIR / f"{_cache_key(url)}"


def get_cached(url: str) -> bytes | None:
    """Return cache-content for URL if fresh, else None."""
    p = _cache_path(url)
    if not p.exists():
        return None
    try:
        age = time.time() - p.stat().st_mtime
    except OSError:
        return None
    if age > _CACHE_TTL_S:
        return None
    try:
        return p.read_bytes()
    except OSError:
        return None


def put_cached(url: str, content: bytes) -> None:
    """Cache content for URL."""
    _ensure_cache_dir()
    _evict_if_large()
    p = _cache_path(url)
    try:
        p.write_bytes(content)
    except OSError:
        pass  # no fail on cache-write


def _evict_if_large() -> None:
    """Keep cache small — remove oldest files beyond _MAX_CACHE_FILES."""
    try:
        entries = sorted(_CACHE_DIR.iterdir(), key=lambda f: f.stat().st_mtime)
    except (OSError, FileNotFoundError):
        return
    if len(entries) > _MAX_CACHE_FILES:
        for f in entries[: len(entries) - _MAX_CACHE_FILES]:
            try:
                f.unlink()
            except OSError:
                pass


def rand_user_agent() -> str:
    """Pick a random user agent from pool."""
    return random.choice(_UA_POOL)


def backoff(attempts_so_far: int) -> float:
    """Seconds to wait before next try (exponential)."""
    # Base 1s, doubles each attempt: 1, 2, 4, 8, ...
    return float(2 ** attempts_so_far)
