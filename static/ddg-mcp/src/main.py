"""ddg-mcp v2 entry-point.

Starts an MCP server (Model Context Protocol) that opencode loads as stdio
client. Logs go to stderr ONLY — stdout is pure JSON-RPC.

Tools:
- search(query, max_results)  -> DDG-HTML web search
- fetch(url)                 -> fetch + strip HTML

No external deps beyond `mcp` (Nixpkgs python314Packages.mcp).
"""

from __future__ import annotations

import sys
import traceback

# Path self-sufficiency — opencode invokes us as a binary; make sure
# our own tree is discoverable regardless of host PYTHONPATH.
import os as _os

_here = _os.path.dirname(_os.path.abspath(__file__))
if _here not in sys.path:
    sys.path.insert(0, _here)
if _here not in [str(p) for p in sys.path]:
    sys.path.append(_here)

# Strict stderr logging — never touch stdout. stdout carries JSON-RPC.
import logging


def _log_err(msg: str) -> None:
    # Route ALL logs to stderr; the host parses stdout as pure JSON-RPC.
    sys.stderr.write(f"[ddg-mcp] {msg}\n")


def _log_err_debug(msg: str) -> None:
    try:
        _log_err(f"[debug] {msg}")
    except Exception:
        pass


# Make logging module go to stderr (not stdout)
logging.basicConfig(
    level=logging.DEBUG,
    stream=sys.stderr,
    format="[ddg-mcp] %(levelname)s %(message)s",
)

# Now wire the mcp library itself
try:
    from mcp.server import mcpserver  # type: ignore

    _log_err_debug("imported mcp.server.mcpserver")

    MCPServer = mcpserver.MCPServer
except Exception as e:
    _log_err(f"mcp import failed: {e}")
    raise


def _build_search(max_results: int = 10) -> "callable":
    from engines import search_ddgo_html

    def search() -> list[dict]:
        raise RuntimeError("bind query first")

    return search_ddgo_html


def _tool_search() -> "callable":
    """Tool: web search via DuckDuckGo HTML endpoint."""
    from engines import search_ddgo_html

    def tool(query: str, max_results: int = 10) -> dict:
        try:
            if not query:
                return {"error": "empty query"}
            results = search_ddgo_html(query)
            results = results[:max(1, int(max_results))]
            return {"results": results}
        except Exception as e:
            tb = traceback.format_exc()
            _log_err(f"search failed: {tb}")
            return {"error": f"search error: {e}"}

    return tool


def _tool_fetch() -> "callable":
    """Tool: fetch URL -> plain text."""
    from engines import fetch_ddgo

    def tool(url: str, max_chars: int = 5000) -> dict:
        try:
            if not url:
                return {"error": "empty url"}
            text = fetch_ddgo(url)
            if len(text) > max(100, int(max_chars)):
                text = text[: max(100, int(max_chars))] + "…[truncated]"
            return {"url": url, "text": text}
        except Exception as e:
            tb = traceback.format_exc()
            _log_err(f"fetch failed: {tb}")
            return {"error": f"fetch error: {e}"}

    return tool


def main() -> None:
    try:
        server = MCPServer()

        # Register: search(query, max_results)
        add_tool = getattr(server, "add_tool", None)
        if add_tool:
            add_tool(name="search", fn=_tool_search())
            add_tool(name="fetch", fn=_tool_fetch())
        else:
            # v1 fallback (still v2-compatible per rules)
            _log_err("MCPServer has no add_tool; registering via tool decorator")
            raise RuntimeError("MCPServer lacks add_tool")

        _log_err("ddg-mcp ready (stdio, v2)")
        import asyncio

        asyncio.run(server.run_stdio_async())
    except Exception as e:
        _log_err(f"main failed: {e}")
        tb = traceback.format_exc()
        _log_err(tb)
        raise


if __name__ == "__main__":
    main()
