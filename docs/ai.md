# AI Stack

Local AI stack on the `amateur` workstation: a **llama.cpp** `llama-server` (ROCm build) serving local models over an OpenAI-compatible API, and three custom **MCP** (Model Context Protocol) stdio servers providing web search, transcription, and NixOS self-administration tools to the agent.

## llama.cpp (`services.llama-cpp`)

Configured in `nixos/modules/workstation/ai.nix`, gated on `anderer.os.workstation.ai` (enabled only on `amateur`).

- Package: `pkgs.llama-cpp-rocm` (AMD ROCm backend; the machine has no NVIDIA GPU).
- Bind: `127.0.0.1:8080` (localhost only — no external exposure, no firewall port opened).
- OpenAI-compatible API under `/v1` (Anthropic-compatible API also available); the model is served under the stable alias `qwen3.8-27b-ud-iq2s-mtp` (`--alias`).
- Models live in the service's StateDirectory `/var/lib/llama-cpp` (DynamicUser, sandboxed — no extra path grants needed):
  - `Qwen3.8-27B-UD-IQ2_S.gguf` (7.9 GB) — main model
  - `mtp-Qwen3.8-27B-Q4_0.gguf` (1.3 GB) — MTP draft model for speculative decoding

Server flags (1:1 ported from the previous ollama config):

| Flag | Value | Why |
| :--- | :--- | :--- |
| `--ctx-size` | `98304` | 96k-token context for long agent sessions (was `OLLAMA_CONTEXT_LENGTH`) |
| `--cache-type-k` / `--cache-type-v` | `q4_0` | quantized KV cache → much larger usable context (was `OLLAMA_KV_CACHE_TYPE`) |
| `--flash-attn` | `on` | attention memory savings (was `OLLAMA_FLASH_ATTENTION=1`) |
| `--batch-size` / `--ubatch-size` | `512` / `512` | prompt-processing batches (Ollama defaults) |
| `--context-shift` | on | sliding window for infinite conversations |
| `--keep` | `4` | tokens kept from the initial prompt when shifting (Ollama default) |
| `--spec-type draft-mtp` + `--spec-draft-model` + `--spec-draft-n-max 4` | | speculative decoding with the MTP draft model, as Ollama did |
| `--n-gpu-layers` | *(unset → `auto`)* | all layers that fit in the RX 6950 XT's VRAM, the rest in RAM |
| `--threads` | *(unset → auto)* | uses the 5800X's physical cores (was `OLLAMA_NUM_THREADS=8`) |
| `--no-webui` | | no built-in web UI (Ollama also ran without one) |

Agent clients are pointed at the local API endpoint `http://127.0.0.1:8080/v1`.

## Supporting tools

- **`amdgpu_top`** + **`taskwarrior3`** — supporting tools from the same machine file (GPU monitoring / task management).

## MCP Servers (`pkgs/by-name/`)

Two hand-rolled MCP stdio servers (source in `static/`, build rules in `pkgs/by-name/`). Both assemble a python wrapper at build time by mirroring the `mcp` package's bootstrap (shebang + `addsitedir` line) so `import mcp.server` resolves without a venv.

| Package | Purpose | Notes |
| :--- | :--- | :--- |
| `ddg-mcp` | DuckDuckGo web search as an MCP tool | FastMCP-based (`mcp` python3.14); DDG HTML engine with a bot-guards workaround (`static/ddg-mcp/src/`) |
| `whisper-mcp` | Audio transcription via `whisper-cpp` (`whisper-cli`) | Tools: `transcribe <audio> [language]`, `list_models`. `whisper-cli` is copied into the package bin so PATH resolution works; model file expected at `~/.local/share/whisper-mcp/ggml-base.en.bin` (override: `WHISPER_MODEL`, CLI path override: `WHISPER_CLI_BIN`) |
| `self-admin-mcp` | NixOS self-administration via `nh` (see `docs/mcp-self-admin.md`) | Plain `subprocess`-driven server (`static/self-admin-mcp/src/main.py`); 8 tools split read/build-only/mutating; host allowlists + content-addressed gate binary (`NH_ADMIN_GATE`) |

## NixOS Channel Monitor

`nixos-channel` (custom package, `pkgs/by-name/nixos-channel.nix`) is a small bash script that queries the NixOS prometheus API (`prometheus.nixos.org`) for the pinned channel (`nixos-unstable-small` by default, override via `NIXOS_CHANNEL`) and reports the channel rev, channel-update age, Hydra build status, and whether the local system build is up to date. Waybar display: the status line is `SYM lokal <loc7> | up <rem7> <WORD>` with per-state CSS classes — `ok` `✓ lokal … | up … OK` (green), `update` `↑ lokal … | up … NEW` (yellow), `fail` `✗ lokal … | up … FAIL` (red), `offline` `? lokal … | up -` (muted); `<loc7>` is the 7-char local system rev, `<rem7>` the remote channel rev (offline: `-`). Output is consumed by the waybar module `custom/nixos-channel` (`home/modules/waybar.nix`).
