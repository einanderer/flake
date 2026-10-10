"""DDG-HTML Engine: DuckDuckGo HTML search + URL fetch."""

from __future__ import annotations

import html as _html_lib
import json
import re
import time
import urllib.error
import urllib.request
from urllib.parse import urlencode

from botguard import (
    backoff,
    get_cached,
    put_cached,
    rand_user_agent,
)

DDG_HTML_URL = "https://html.duckduckgo.com/html/"


def _strip_tags(raw: str) -> str:
    """Strip HTML tags and decode entities."""
    cleaned = _TAG_RE.sub(" ", raw or "").strip()
    cleaned = _html_lib.unescape(cleaned)
    return re.sub(r"\s+", " ", cleaned)


_TAG_RE = re.compile(r"<[^>]+>")


def _parse_ddg_html(results_html: str) -> list[dict]:
    """Best-effort DDG HTML result parser → list[{title, url, snippet}]."""
    results: list[dict] = []
    blocks = re.split(r'<div class="result[ \t]+"', results_html)
    for blk in blocks:
        a_match = re.search(
            r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>', blk[:800], re.DOTALL
        )
        if not a_match:
            continue
        url = a_match.group(1)
        raw_title = a_match.group(2)
        title = _strip_tags(raw_title)
        snippet_m = re.search(
            r'class="result__snippet"[^>]*>(.*?)(?:</div>|$)', blk, re.DOTALL
        )
        snippet = _strip_tags(snippet_m.group(1)) if snippet_m else ""
        results.append(
            {
                "title": title[:200],
                "url": url[:500],
                "snippet": snippet[:400],
            }
        )
    return results


def search_ddgo_html(query: str) -> list[dict]:
    """Search DuckDuckGo HTML endpoint; fallback → Instant Answer API."""
    # Cache key is the same URL we'd call without q.
    cache_key = "search:" + query
    cached = get_cached(cache_key)
    if cached is not None:
        return _parse_ddg_html(cached.decode(errors="replace"))

    ua = rand_user_agent()
    req = urllib.request.Request(
        DDG_HTML_URL + "?" + urlencode({"q": query, "kl": "wt-en"}),
        headers={
            "User-Agent": ua,
            "Accept": "text/html",
        },
    )

    last_err: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read()
            put_cached(cache_key, raw)
            return _parse_ddg_html(raw.decode(errors="replace"))
        except urllib.error.HTTPError as e:
            last_err = e
            time.sleep(backoff(attempt))
            continue
        except Exception as e:
            last_err = e
            time.sleep(backoff(attempt))
            continue

    raise RuntimeError(f"DDG search failed: {last_err}")


def fetch_ddgo(url: str) -> str:
    """Fetch URL → plain text (stripped). Cache hit: cached text."""
    cached_text = get_cached(url)
    if cached_text is not None:
        return cached_text.decode(errors="replace")

    ua = rand_user_agent()
    req = urllib.request.Request(
        url, headers={"User-Agent": ua, "Accept": "text/html"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
            text = raw.decode(errors="replace")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Fetch HTTP {e.code}: {url}") from e
    except Exception as e:
        raise RuntimeError(f"Fetch failed: {e}: {url}") from e

    body = _strip_tags(text)
    # Cache the stripped text (not raw HTML)
    put_cached(url, body.encode(errors="replace"))
    return body
