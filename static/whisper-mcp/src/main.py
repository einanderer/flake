"""whisper-mcp entry point — MCP stdio server for transcribing audio with
whisper.cpp (a C/C++ port of OpenAI Whisper).

Two tools:
  - transcribe <audio> [language] : return transcribed plain text
  - list_models                   : report where the ggml model file is
                                       expected, and whether it's present

The MCP wrapper (`bin/whisper-mcp`) is a python bootstrap assembled at
install-time that:
  1) adds every transitive mcp+dep site-packages to `sys.path`
     (mirroring the mcp package's own bootstrap)
  2) imports this module, and calls `main()` (FastMCP server in stdio)
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

# the Nix installPhase `cp`'d the `bin/whisper-cli` into `$out/bin`, so
# the wrapper bin-dir is `$out/bin`.  `shutil.which` finds it there.
# If not, fall back to PATH.


def _log_err(msg: str) -> None:
    """Log to stderr (MCP's stdio — stderr goes to the log, not the pipe)."""
    sys.stderr.write(f"[whisper-mcp] {msg}\n")


def _default_model_path() -> str:
    """Default path where the ggml model file lives; override via env."""
    return os.environ.get(
        "WHISPER_MODEL",
        os.path.abspath(os.path.join(
            os.environ["HOME"],
            ".local",
            "share",
            "whisper-mcp",
            "ggml-base.en.bin",
        )),
    )


def _find_whisper_cli() -> str:
    """Resolve `whisper-cli` via same-dir / PATH lookup."""
    override = os.environ.get("WHISPER_CLI_BIN")
    if override:
        if not (os.access(override, os.F_OK) and os.access(override, os.X_OK)):
            raise RuntimeError(f"WHISPER_CLI_BIN={override!r} is not an executable file.")
        return override

    # wrapper bin/ (installPhase copied `whisper-cli` into `$out/bin`).
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join("/nix", "bin", "whisper-cli"),           # wrapper bin
        os.path.join(here, "whisper-cli"),                   # python package dir
        sys.executable,                                     # fallback
    ]
    for c in candidates:
        if os.access(c, os.X_OK):
            return c

    found = shutil.which("whisper-cli")
    if found:
        return found

    raise RuntimeError(
        "whisper-cli not found on PATH and no wrapper bin is in reach.",
    )


def _transcribe(
    audio: str,
    language: str = "en",
) -> dict:
    """Run a single whisper-cli call; returns the transcribed text."""
    if not audio:
        return {"error": "empty audio path"}

    model_path = _default_model_path()
    if not os.path.isfile(model_path):
        return {
            "error": "whisper.cpp model missing",
            "expected_path": model_path,
            "model_bytes": 142_000_000,
            "hint": "download first: `whisper-mcp-setup` or equivalent.",
        }

    cli = _find_whisper_cli()
    cmd = [
        cli,   # the `bin/whisper-cli` store
        "-m", model_path,
        "-f", audio,
        "-l", language if language else "en",
        "-np",
    ]
    _log_err(f"exec: {subprocess.list2cmdline(cmd)}")

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        _log_err("whisper-cli timed out (600s)")
        return {"error": "whisper-cli timed out after 600s"}
    except OSError as e:
        _log_err(f"whisper-cli spawn failed: {e}")
        return {"error": f"whisper-cli failed to spawn: {e}"}

    if proc.returncode != 0:
        _log_err(f"whisper-cli rc={proc.returncode}")
        _log_err(f"stderr: {proc.stderr[:500]!r}")
        return {
            "error": f"whisper-cli exited rc={proc.returncode}",
            "stderr_first_500": (proc.stderr or "")[:500],
        }

    text = (proc.stdout or "").strip()
    return {"audio": audio, "text": text}


def _list_models() -> dict:
    """Report whether the ggml model file is on disk."""
    model_path = _default_model_path()
    exists = os.path.isfile(model_path)
    size = os.path.getsize(model_path) if exists else 0
    return {
        "model": model_path,
        "exists": exists,
        "size_bytes": size,
        "exists_in_mib": (size // (1024 * 1024)) if exists else 0,
    }


def main() -> None:
    """MCP server entry point — imports `mcp` on demand."""
    try:
        from mcp.server import FastMCP

        _log_err("imported mcp.server.FastMCP")
        server = FastMCP("whisper-mcp")

        @server.tool(
            name="transcribe",
            title="Whisper transcription of an audio file",
            description=(
                "Transcribe an audio file (wav/mp3/ogg/flac) to English "
                "plain text using whisper.cpp. Requires `list_models` to "
                "confirm `ggml-base.en.bin` is present first; if it's not, "
                "tell the user to download it first via the MCP-side "
                "setup; do NOT auto-run downloads."
            ),
        )
        def tool_transcribe(audio: str, language: str = "en") -> dict:
            return _transcribe(audio, language)

        @server.tool(
            name="list_models",
            title="Inspect whisper.cpp model file state",
            description=(
                "Report where the ggml model file is expected on this "
                "host, and whether + how many MB it occupies. Pair with "
                "transcribe to give the LLM visibility before it fires "
                "transcribe with no audio on disk."
            ),
        )
        def tool_list_models() -> dict:
            return _list_models()

        _log_err("whisper-mcp ready (stdio)")
        server.run(transport="stdio")

    except Exception as e:  # pragma: no cover
        _log_err(f"main failed: {e}")
        import traceback
        _log_err(traceback.format_exc())
        raise


if __name__ == "__main__":
    main()
