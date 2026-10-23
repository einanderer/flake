# `nh` CLI Map — for the NixOS self-admin MCP

Reference of **what `nh` 4.4.2 (`nix-community/nh`) can do** and **which
commands an MCP client may run safely**, split into *read* vs *mutating*
classes, including remote targets, privilege-elevation, and the constraints
observed on this box.

> Status: **planning reference, not yet committed.** Facts are tagged
> `[observed]` (verified on this machine this session) or `[to-verify]`
> (needs a live run before the MCP relies on it).

---

## 1. Toolchain

- Binary: `/run/current-system/sw/bin/nh`, self-reports `nh 4.4.2`.
- Repo: `nix-community/nh` (EUPL-1.2). Stable release ships via Nixpkgs as `nh`.
- Replaces **both** `nixos-rebuild` and most of `home-manager`'s CLI.
- **It does not cover** raw Nix primitives: `nix eval`, `nix build <drv>`,
  `nix flake update/lock`, `nix develop`, `git`, `sops`. Those still run as
  plain Nix/git/sops in the dev shell (per `AGENTS.md`). The MCP can shell out
  to them separately if needed.

## 2. Global / common flags

| Flag | Meaning |
|---|---|
| `-v / -q` | verbosity |
| `-e/--elevation-strategy <STR>` or `$NH_ELEVATION_STRATEGY` | `auto` \| `none` \| `passwordless` \| path-to-elevation-program. `auto` probes `doas, sudo, run0, pkexec` in order. **This is the whole security model for an MCP — see §4.** |
| INSTALLABLE positional | `FLAKEREF[#ATTRPATH]` (env `$NH_FLAKE` / `$NH_OS_FLAKE`), or `-f/--file <file> [attr]`, or `-e/--expr <expr> [attr]`, or an absolute path / symlink to a store path. |
| `-- <EXTRA_ARGS>...` | **forwarded verbatim to `nix build`** (so `--no-net`, `--offline`, `--impure`, `--refresh`, `--commit-lock-file`, … are usable). |

## 3. Command map

### 3.1 `nh os <cmd>` (NixOS)

| cmd | What it does | Class | Needs root? | Key flags |
|---|---|---|---|---|
| `info` `[observed]` | List current-system generations (id, date, nver, kernel, confRev, spec, size) | **read** | no | `-P/--profile` (default `/nix/var/nix/profiles/system`), `--fields` |
| `build` | Build the system derivation only; **does not activate, does not touch boot** | build-only (safe-ish) | no | full nix-build forwarding |
| `switch` | Build + **activate** + set as boot default | **mutating** | **yes** | `-n/--dry`, `-a/--ask`, `-H/--hostname`, `-s/--specialisation`, `--no-validate` |
| `boot` | Build + set boot default; **activated on next reboot, not now** | **mutating** | **yes** | same flags |
| `test` | Build + activate **transiently** (gone on reboot, doesn't persist boot) | **mutating** (but revertible on reboot) | **yes** | same flags |
| `repl` | Load the system attrset into the Nix REPL | read (interactive) | no | — |
| `rollback` | Activate a previous generation | **mutating** (recovery) | **yes** | `-t/--to <GEN>` (default: previous), `-n/--dry`, `-s/-S`, `-R/--bypass-root-check` |
| `build-vm` | Build a VM image | build-only | no | — |
| `build-image` | Build a disk image | build-only | no | — |

Dry-run semantics (`-n`): `[to-verify]` "Only print actions, without
performing them". For `switch`/`rollback` it should print the unit
start/stop list **without** applying. Confirm on a real run whether it still
elevates when it *computes* the action list.

### 3.2 `nh home <cmd>` (Home Manager)

| cmd | Does | Class | Needs root? |
|---|---|---|---|
| `build` | Build HM derivation only | build-only (safe-ish) | no |
| `switch` | Build + activate HM (user profile) | **mutating** (user-level, no reboot) | typically no (user profile) |
| `repl` | Load HM attrset in REPL | read (interactive) | no |

Notes: `switch`/`build`/`repl` take the same INSTALLABLE + `-e` flags as `os`.
HM activation targets the user profile → usually no root needed, **but
still mutating** (rewrites `~/.local/state/...`, re-homes packages).

### 3.3 `nh search <cmd>` — all **read** (no root, no system mutation) `[observed]`

| cmd | Source | Notes |
|---|---|---|
| `packages <q>` | search.nixos.org (live, network) | `-l/--limit` (def 30), `-c/--channel` (def `nixos-unstable`), `-P/--platforms` |
| `options <q>` | search.nixos.org (live, network) | same; NixOS + home-manager options |
| `offline --db <PATH> <q>` | **local SPAM DB, no network** | `-D/--db` repeatable (`$NH_OFFLINE_DB`). `[to-verify]` a DB must be fetched first (input `nix-index-database` is already in the flake) |
| `prs <q>` | nixpkgs pull requests | — |
| `issues <q>` | nixpkgs issues (excl. PRs) | — |

→ `search` is an **offline-online package/option lookup**. It overlaps with the
"Type 1" hallucination-killer (`mcp-nixos`/`mcp-nix`) and can replace it if a
SPAM DB is materialized.

### 3.4 `nh clean <cmd>` — all **destructive** (needs care)

| cmd | What | Class |
|---|---|---|
| `user` | GC current user's profiles | **destructive** (deletes generations/store paths) |
| `all` | Clean all profiles | **destructive** |
| `profile <PROFILE>` | Clean one profile | **destructive** |

Common: `-k/--keep` (def 1), `-K/--keep-since <humantime>` (def `0h`).
An MCP should expose this only behind an explicit confirmation + keep-at-least-N
guard, **never** on the hot path.

## 4. Privilege elevation on `amateur` (the whole self-admin story) `[observed]`

- User `anderer` ∈ **`wheel`** (so *can* sudo).
- Elevation programs on PATH: **`run0`, `pkexec`, `sudo`** (`doas`: not installed).
- `sudo -n true` → **`A terminal is required to authenticate`** → there is
  **no passwordless sudo** for this user.

**Consequence (design driver):** `auto` elevation strategy will pick `sudo`
first and **fail non-interactively** for any *mutating* `os` command.
So the MCP has exactly one of these, all requiring a decision:

1. **Read-only scope** — serve `os info`, `build`, `search`, `repl`. No
   elevation ever. Safe but **cannot** `switch`/`boot`/`rollback`/`clean`.
2. **NOPASSWD sudoers rule scoped to `nh`/`sudo -H <nh> os …`** — non-interactive
   `switch`/`rollback` become possible from the MCP. (security decision; this is
   the normal way to make it work)
3. **polkit** — interactive/agent approval, not friendly to a headless agent.

`switch`/`boot`/`test`/`rollback`/`clean` are **impossible from this MCP without
(2)**; `home switch`, `build`, `info`, `search` work fine without any of the above.

## 5. Remote deployments `[observed flags]`

- `--target-host <H>` — build here, **activate on host H over SSH**.
- `--build-host <H>` — build on H, activate locally (or paired with target).
- `-H/--hostname <H>` — select the `nixosConfigurations.<H>` entry (defaults:
  local hostname locally, target hostname remotely).
- Remote activation runs *on the target*; its own elevation story applies there
  (typically `--elevation-strategy passwordless` with a NOPASSWD entry on the target).

Hosts in this repo (`machines/`): `amateur`, `bettenlager`, `server` (hostname
`server`), `tentacle`, `trolllollo`. AGENTS.md calls out 4 deploy targets
(`tentacle` = Hetzner VPS gateway **critical**, `trolllollo` **critical**,
`amateur` core, `bettenlager` non-critical).

> `[to-verify]` remote `--target-host` to `tentacle`/`trolllollo` from this MCP
> needs a target-side elevation strategy decided + SSH key present. **Default
> should be a hard host allowlist, empty until configured.**

## 6. Readable vs mutating — summary table for the MCP

| MCP tool (proposed) | nh call | Class | Root? |
|---|---|---|---|
| `os_generations` | `nh os info` | read | no |
| `os_build` | `nh os build` | build-only | no |
| `os_dryrun` | `nh os switch -n …` | dry (read-ish) | `[to-verify]` |
| `os_switch` | `nh os switch` | **mutating** | yes |
| `os_boot` | `nh os boot` | **mutating** | yes |
| `os_test` | `nh os test` | **mutating** (reversible) | yes |
| `os_rollback` | `nh os rollback -t GEN` | **mutating** (recovery) | yes |
| `home_switch` | `nh home switch` | mutating (user) | no |
| `search_pkgs` / `search_options` | `nh search …` | read | no |

## 7. Environment / wiring facts for the OpenCode config

- `cwd` must be the flake dir (`/home/anderer/flake`) so `nh os switch .`
  resolves `.#amateur`.
- `NH_FLAKE=` / `NH_OS_FLAKE=` env can pin the installable explicitly.
- `NH_ELEVATION_STRATEGY=` env controls elevation per-process (overrides `-e`).
- `NH_OFFLINE_DB=` sets the SPAM DB path for `search offline`.
