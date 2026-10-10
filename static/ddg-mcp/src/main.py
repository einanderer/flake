"""ddg-mcp entry-point — MCP stdio server for DuckDuckGo search."""

from __future__ import annotations

import os as _os
import sys
import traceback

_here = _os.path.dirname(_os.path.abspath(__file__))
if _here not in sys.path:
    sys.path.insert(0, _here)

import logging

logging.basicConfig(
    level=logging.DEBUG,
    stream=sys.stderr,
    format="[ddg-mcp] %(levelname)s %(message)s",
)


def _log_err(msg: str) -> None:
    sys.stderr.write(f"[ddg-mcp] {msg}\n")


def main() -> None:
    try:
        from mcp.server import FastMCP

        _log_err("imported mcp.server.FastMCP")

        server = FastMCP("ddg-mcp")

        def _search(query: str, max_results: int = 10) -> dict:
            from engines import search_ddgo_html

            try:
                if not query:
                    return {"results": [], "error": "empty query"}
                results = search_ddgo_html(query)
                n = max(1, int(max_results))
                return {"results": results[:n]}
            except Exception as e:
                _log_err(f"search failed: {e}")
                return {"error": f"search error: {e}"}

        def _fetch(url: str, max_chars: int = 5000) -> dict:
            from engines import fetch_ddgo

            try:
                if not url:
                    return {"error": "empty url"}
                text = fetch_ddgo(url)
                limit = max(100, int(max_chars))
                if len(text) > limit:
                    text = text[:limit] + "…[truncated]"
                return {"url": url, "text": text}
            except Exception as e:
                _log_err(f"fetch failed: {e}")
                return {"error": f"fetch error: {e}"}

        @server.tool(
            name="search",
            title="DuckDuckGo HTML search",
            description=(
                "Search DuckDuckGo's HTML endpoint for a query. "
                "Returns a list of {title, url, snippet} objects. "
                "Use this for web research when another search API is unavailable."
            ),
        )
        def tool_search(query: str, max_results: int = 10) -> dict:
            return _search(query, max_results=max_results)

        @server.tool(
            name="fetch",
            title="Fetch URL text",
            description=(
                "Fetch a URL and return its content as stripped plain text "
                "(HTML tags and entities removed). "
                "Content is capped at max_chars."
            ),
        )
        def tool_fetch(url: str, max_chars: int = 5000) -> dict:
            return _fetch(url, max_chars=max_chars)

        _log_err("ddg-mcp ready (stdio)")

        # server.run() is synchronous — drives anyio internally
        server.run(transport="stdio")

    except Exception as e:
        _log_err(f"main failed: {e}")
        tb = traceback.format_exc()
        _log_err(tb)
        raise


if __name__ == "__main__":
    main()
