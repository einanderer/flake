"""DDG-HTML Engine: sucht auf html.duckduckgo.com, liefert (title, url, snippet).

- Keine offizielle JSON-API, sondern HTML-Endpunkt
- Fallback: DuckDuckGo Instant Answer API (api.duckduckgo.com) wenn erreichbar
- Returns list[dict]
"""

from __future__ import annotations

import html as _html_lib
import re
from urllib.parse import urlencode

from botguard import (
    backoff,
    get_cached,
    put_cached,
    rand_user_agent,
)

DDG_HTML_URL = "https://html.duckduckgo.com/html/"
DDG_IA_URL = "https://api.duckduckgo.com/"

_TAG_RE = re.compile(r"<[^>]+>")


def _strip_tags(raw: str) -> str:
    cleaned = _TAG_RE.sub(" ", raw or "").strip()
    cleaned = _html_lib.unescape(cleaned)
    # collapse whitespace
    return re.sub(r"\s+", " ", cleaned)


def _parse_ddg_html(results_html: str) -> list[dict]:
    """Best-effort parse of DDG HTML results.

    DDG HTML result items are typically:
        <div class="result__a">Title</div>
        <div class="result__snippet">snippet</div>
    or
        <a class="result__a" href="URL">Title</a>

    We return a list of dicts: {title, url, snippet}
    """

    results: list[dict] = []
    # Split on result blocks (best-effort)
    blocks = re.split(r"<div class=\"result[ \t]+\"?\s*", results_html)
    for blk in blocks:
        if not blk:
            continue
        # Extract title + url from <a> or title
        try:
            a_match = re.search(
                r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>', blk[:500], re.DOTALL
            )
            if a_match:
                url = a_match.group(1)
                raw_title = a_match.group(2)
                title = _strip_tags(raw_title)
            else:
                continue
        except Exception:
            continue
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
    """Search DuckDuckGo HTML endpoint. Returns list of results.

    Fallback: Instant Answer API if HTML fails.
    """
    import urllib.error
    import urllib.request

    # Try cache first
    cache_url = DDG_HTML_URL + "?" + urlencode({"q": query})
    cached = get_cached(cache_url)
    if cached:
        return _parse_ddg_html(cached.decode(errors="replace"))

    ua = rand_user_agent()
    req = urllib.request.Request(
        DDG_HTML_URL,
        data=urlencode({"q": query}).encode(),
        headers={
            "User-Agent": ua,
            "Accept": "text/html,application/xhtml+xml",
        },
        method="POST",
    )
    # NOTE: DDG html endpoint uses POST but some prefer GET — use GET as safer
    req = urllib.request.Request(
        DDG_HTML_URL + "?" + urlencode({"q": query, "kl": "wt-en"}),
        headers={
            "User-Agent": ua,
            "Accept": "text/html",
        },
    )

    import time as _t

    last_err: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                if resp.status in (403, 429, 503):
                    last_err = RuntimeError(f"HTTP {resp.status}")
                    time.sleep(backoff(attempt))
                    continue
                # 200
                raw = resp.read()
                put_cached(cache_url, raw)
                return _parse_ddg_html(raw.decode(errors="replace"))
        except urllib.error.HTTPError as e:
            last_err = e
            _t.sleep(backoff(attempt))
            continue
        except Exception as e:
            last_err = e
            _t.sleep(backoff(attempt))
            continue

    # Fallback: Instant Answer API
    try:
        ia_url = DDG_IA_URL + "?" + urlencode(
            {"q": query, "format": "json"}
        )
        req2 = urllib.request.Request(
            ia_url,
            headers={"User-Agent": rand_user_agent()},
        )
        import json as _json  # type: ignore

        with urllib.request.urlopen(req2, timeout=10) as resp:
            if resp.status == 200:
                data = _json.loads(resp.read())
                if isinstance(data, dict) and "results" in data:
                    out: list[dict] = []
                    for r in data.get("results", []):
                        if isinstance(r, dict):
                            out.append(
                                {
                                    "title": str(r.get("heading", "") or "")[:200],
                                    "url": str(r.get("url", "") or "")[:500],
                                    "snippet": str(r.get("text", "") or "")[:400],
                                }
                            )
                    return out
    except Exception:
        pass

    raise RuntimeError(f"DDG search failed: {last_err}")


def fetch_ddgo(url: str) -> str:
    """Fetch a URL and return plain text (best-effort, not markdown-convert)."""
    import urllib.error
    import urllib.request

    cached = get_cached(url)
    if cached:
        return cached.decode(errors="replace")

    ua = rand_user_agent()
    req = urllib.request.Request(
        url, headers={"User-Agent": ua, "Accept": "text/html"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
            put_cached(url, raw)
            text = raw.decode(errors="replace")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Fetch HTTP {e.code}: {url}")
    except Exception as e:
        raise RuntimeError(f"Fetch failed: {e}: {url}")

    # Simplest: strip HTML tags
    body = _strip_tags(text)
    return body

