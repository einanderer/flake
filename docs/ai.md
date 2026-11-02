# AI Stack

Local AI stack on the `amateur` workstation: an ROCm build of **ollama** serving local models over LLM inference, **opencode** as the agent client, and three custom **MCP** (Model Context Protocol) stdio servers providing web search, transcription, and NixOS self-administration tools to the agent.

## Ollama (`services.ollama`)

Configured in `nixos/modules/workstation/ai.nix`, gated on `anderer.os.workstation.ai` (enabled only on `amateur`).

- Package: `pkgs.ollama-rocm` (AMD ROCm backend; the machine has no NVIDIA GPU).
- Bind: `127.0.0.1:11434` (localhost only — no external exposure).
- Environment tuning:

| Variable | Value | Why |
| :--- | :--- | :--- |
| `OLLAMA_CONTEXT_LENGTH` | `98304` | 96k-token context for long agent sessions |
| `OLLAMA_KEEP_ALIVE` | `2h` | keep models loaded between requests |
| `OLLAMA_MAX_LOADED_MODELS` / `OLLAMA_NUM_PARALLEL` | `1` | one model at a time for the 16 Gi VRAM budget |
| `OLLAMA_FLASH_ATTENTION` | `1` | attention memory savings |
| `OLLAMA_KV_CACHE_TYPE` | `q4_0` | quantized KV cache → much larger usable context |
| `OLLAMA_NUM_THREADS` | `8` | matches the 5800X's 8 physical cores |

Agent clients (e.g. opencode) are pointed at the local API endpoint `http://127.0.0.1:11434/v1`.

## Agent Client

- **`opencode`** — installed as a `environment.systemPackages` entry on `amateur` (`machines/amateur.nix`). Its config (`~/.config/opencode/opencode.jsonc`) and plugins live in the user's home and are **not** managed by this flake; they are maintained locally.
- **`amdgpu_top`** + **`taskwarrior3`** — supporting tools from the same machine file (GPU monitoring / task management).

## MCP Servers (`pkgs/by-name/`)

Two hand-rolled MCP stdio servers (source in `static/`, build rules in `pkgs/by-name/`). Both assemble a python wrapper at build time by mirroring the `mcp` package's bootstrap (shebang + `addsitedir` line) so `import mcp.server` resolves without a venv.

| Package | Purpose | Notes |
| :--- | :--- | :--- |
| `ddg-mcp` | DuckDuckGo web search as an MCP tool | FastMCP-based (`mcp` python3.14); DDG HTML engine with a bot-guards workaround (`static/ddg-mcp/src/`) |
| `whisper-mcp` | Audio transcription via `whisper-cpp` (`whisper-cli`) | Tools: `transcribe <audio> [language]`, `list_models`. `whisper-cli` is copied into the package bin so PATH resolution works; model file expected at `~/.local/share/whisper-mcp/ggml-base.en.bin` (override: `WHISPER_MODEL`, CLI path override: `WHISPER_CLI_BIN`) |
| `self-admin-mcp` | NixOS self-administration via `nh` (see `docs/mcp-self-admin.md`) | Plain `subprocess`-driven server (`static/self-admin-mcp/src/main.py`); 8 tools split read/build-only/mutating; host allowlists + content-addressed gate binary (`NH_ADMIN_GATE`); opencode entry in `~/.config/opencode/opencode.jsonc` (local config, not in this repo) |

Validation helper: `scripts/validate_mcp.sh` (local-only, git-ignored) checks the opencode config and MCP server binaries.

## NixOS Channel Monitor

`nixos-channel` (custom package, `pkgs/by-name/nixos-channel.nix`) is a small bash script that queries the NixOS prometheus API (`prometheus.nixos.org`) for the pinned channel (`nixos-unstable-small` by default, override via `NIXOS_CHANNEL`) and reports the channel rev, channel-update age, Hydra build status, and whether the local system build is up to date. Waybar display: the status line is `SYM lokal <loc7> | up <rem7> <WORD>` with per-state CSS classes — `ok` `✓ lokal … | up … OK` (green), `update` `↑ lokal … | up … NEW` (yellow), `fail` `✗ lokal … | up … FAIL` (red), `offline` `? lokal … | up -` (muted); `<loc7>` is the 7-char local system rev, `<rem7>` the remote channel rev (offline: `-`). Output is consumed by the waybar module `custom/nixos-channel` (`home/modules/waybar.nix`).
