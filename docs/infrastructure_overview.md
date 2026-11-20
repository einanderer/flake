# Infrastructure Overview

This document provides a comprehensive overview of the managed NixOS infrastructure, including hosts, roles, networking, shared configurations, and the repository layout.

## 🖥️ Hosts & Roles

| Hostname | Type | Role | Hardware / OS Notes |
| :--- | :--- | :--- | :--- |
| `amateur` | Local Desktop | Core Deployment & Dev | AMD CPU/GPU, Gaming, Streaming, AI, Libvirt (see [amateur_hardware.md](./amateur_hardware.md)) |
| `trolllollo` | Notebook | Mobile Workstation | ThinkPad T470s, Remote Play enabled |
| `bettenlager` | Notebook | Mobile Workstation | ThinkPad X230, Remote Play enabled |
| `tentacle` | VPS (Hetzner) | VPN Gateway | Critical Infrastructure, WireGuard Hub (`ttvpn`) |
| `server` | Server | Network Uplink | Connectivity provider for the stack |

All workstation hosts share the NixOS-side Home Manager setup (`home/anderer.nix` + `home/modules/*`), imported via `nixos/modules/home.nix`.

## 🌐 Network Architecture (ttvpn)

The infrastructure uses a private WireGuard network managed by `tentacle`.

- **IPv4 Range:** `10.111.101.0/24`
- **IPv6 Range:** `fd72:db04:ef1a::/48`
- **Hub:** `tentacle` (Listening on port `52342`)
- **Peers:**
    - `GL-AX1800`
    - `WSL2-spare`
    - `trolllollo`
    - `iPhone12`

## 📂 Repository Layout

```
machines/     Host-specific NixOS configurations (one file per host, all built in machines/default.nix)
nixos/        Shared NixOS module tree, exposed as nixosModules.all (see below)
home/         Home Manager config: anderer.nix (entry) + per-topic modules/ + nixvim/ (LSP/editor setup)
pkgs/         Custom packages; pkgs/by-name/* auto-collected into packages.*
static/       Non-Nix source trees and assets (ddg-mcp, whisper-mcp, wallpapers, patches, ...)
scripts/      Local dev helpers (git-ignored; machine-local only)
secrets/      Per-host SOPS files (secrets.yaml is the shared/global one)
archived/     Retired modules preserved for reference (server monitoring stack, spotify-unfree)
docs/         This documentation (infrastructure overview, hardware specs, AI stack)
```

### NixOS module tree (`nixos/modules/`)

| Directory | Contents |
| :--- | :--- |
| `base/` | Cross-cutting modules: `networking`, `nginx`, `openssh` (PQ-only KEX), `postgresql`, `tools`, `zram` (aggressive tmpfs/swap tuning) |
| `hardware/` | CPU/GPU detection modules, ThinkPad per-model modules (t470s, x230) |
| `network/` | `server-uplink`, `tentacle-edge`, `ttvpn` (WireGuard hub/client) |
| `profiles/` | Workstation profiles: `workstation-base` (tz, boot, workstation role), `workstation-desktop`, `workstation-laptop` |
| `workstation/` | GUI/dev role modules: `ai.nix` (llama.cpp server), audio, Bluetooth, boot, cursor, filesystems, fonts, gaming (streaming, Remote Play), nix, nvidia, programs, udev, uxplay, virtualisation, wayland |
| (top level) | `core.nix` (nix, nixpkgs, sops, nixos-version), `home.nix` (user + Home Manager), `secureboot.nix` (Lanzaboote), `nixpkgs.nix` (unfree allow-lists) |

Machines select from this tree via options under `anderer.*` (e.g. `anderer.profiles.workstationDesktop.enable`, `anderer.os.workstation.ai`, `anderer.hardware.thinkpad.t470s`).

## 🤖 AI Stack

Local AI stack on the `amateur` workstation: **llama.cpp** (ROCm build of `llama-server`) with tuned server flags, and three custom **MCP (Model Context Protocol)** stdio servers built in `pkgs/by-name/` (`ddg-mcp`: DuckDuckGo search; `whisper-mcp`: whisper.cpp transcription).

Configured in `nixos/modules/workstation/ai.nix`, `machines/amateur.nix`. Details, env-var rationale, and the MCP packages: **[ai.md](./ai.md)**.

## 🎨 Shared Configurations

### User Profiles (`anderer`)
Workstations share common profiles and aesthetic settings via Home Manager and Stylix.

- **Stylix Theme:** Base16 `chalk.yaml` (Dark Mode)
- **Fonts:**
    - Monospace: `CommitMono`
    - Sans-Serif: `Inter`
    - Serif: `Noto Serif`
- **Terminal:** `tmux` (configured), `btop`/`bottom` (monitoring), `eza` (ls replacement).
- **Editor:** [nixvim](https://github.com/nix-community/nixvim) (built as `packages.nvim` with the shared `home/nixvim/` module set).

### System-Wide Standards
- **Secrets Management:** Managed via `sops-nix`.
- **Package Management:** Nix Flakes.
- **Versioning:** system version suffix encodes nixpkgs rev + this repo's git rev (see `core.nix`, `system.nixos.*`).
- **Uptime visibility:** `nixos-channel` (custom package) polls the NixOS prometheus API for channel/build status and renders it into waybar as `custom/nixos-channel`.

## 🏗️ CI & Development Workflow

- **Dev Shell** (`nix develop`): `sops`, `ssh-to-age`, `nix-fast-build`, `nixos-anywhere`, plus treefmt and pre-commit inputs from `flake-root`.
- **CI** (`.github/workflows/check.yaml`): runs on PRs and pushes to `main` — installs **Lix**, attaches the **cachix** cache, then runs `nix-fast-build` flake checks.
- **Linting/Formatting:** `treefmt.nix` plus `git-hooks.nix` pre-commit hooks.
- **Ad-hoc Tools:** For temporary tools not in the dev shell, use `nix shell -p <package>` or `nix run nixpkgs#<package>` instead of imperative package managers.
