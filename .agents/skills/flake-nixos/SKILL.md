---
name: flake-nixos
description: Manage the 4-host NixOS flake (amateur, tentacle, trolllollo, bettenlager) via `nh` commands. Repo layout, host inventory, dev workflow and commit discipline. Use when building/switching/rolling back the flake, touching machines/, nixos/, home/, pkgs/ or doing any system-admin work in this flake.
---

# flake-nixos

This flake manages 4 NixOS hosts. Read `AGENTS.md` and `docs/nh-cli-map.md` for full detail; this skill is the quick-start.

## Core commands

```bash
# Local apply (host: amateur)
nh os switch .

# Remote apply
nh os switch .#HOSTNAME --target-host HOSTNAME
```

For dry runs, rollbacks and builds use the `self_admin` MCP server
(`os_dryrun`, `os_rollback`, `os_build`) or the matching `nh` commands.

## Host inventory

| Hostname | Type | Role | Notes |
|---|---|---|---|
| `amateur` | Local Desktop | Gaming, Streaming Server, Dev, Multimedia | **Core Deployment Machine**. Remote builds happen here. |
| `tentacle` | External VPS (Hetzner) | VPN Gateway | **Critical Infrastructure**. SSH or Hetzner Web Console. |
| `trolllollo` | Local Notebook | Multimedia, Gaming, Streaming, Dev | **Critical**. High priority. |
| `bettenlager` | Local Notebook | Multimedia, Streaming Client | Non-critical consumer device. |

## Repo structure

- `machines/` — host-specific NixOS configurations
- `nixos/` — system-wide modules/profiles (`base/`, `hardware/`, `network/`, `profiles/`, `workstation/`)
- `home/` — Home Manager (incl. `nixvim/`)
- `pkgs/by-name/` — auto-collected custom packages
- `secrets/` — SOPS-encrypted (see `sops-secrets` skill)
- `docs/` — infra overview, hardware specs, AI stack
- `static/` — non-Nix sources/assets
- `scripts/` — local dev helpers, git-ignored, machine-local only

## Dev workflow

- **Dev Shell:** `nix develop` — has `sops`, `ssh-to-age`, `nixos-anywhere`, treefmt, pre-commit.
- **Ad-hoc tools:** `nix shell -p <package>` or `nix run nixpkgs#<package>`. Do not use imperative package managers for one-off tools.
- **Linting/Formatting:** `treefmt` via `git-hooks.nix` pre-commit hook. Format with the treefmt binary, not manually.
- **Commit discipline (hard rules):**
  1. Commit each verified change as its **own logical step** the moment it is verified (build/test/read-back).
  2. Working directory is **clean** after every step — no WIP, no half-applied files, no unstaged verified changes.
  3. Never mix two steps into one commit.

## Boundaries

- MCP `os_switch`/`os_rollback` are **mutating** and gated (confirm + allowlisted host + gate).
- `os_dryrun` currently maps to `nh os switch -n` (build-only in nh 4.5.0) — it does NOT preview activation.
- Remote hosts are **not** in the MCP allowlist — remote switches run via Bash `nh os switch .#HOST --target-host HOST`.
