# `nh` CLI Map — for the NixOS self-admin MCP

Reference of **what `nh` (`nix-community/nh`) can do** and **which
commands an MCP client may run safely**, split into *read* vs *mutating*
classes, including remote targets, privilege-elevation, and the constraints
observed on this box.

> Status: **implemented & committed** (`9554b89`); the MCP documented here
> shipped as `self-admin-mcp` — see `docs/mcp-self-admin.md`. Facts are
> tagged `[observed]` (verified on this machine) or `[to-verify]` (needs a
> live run before the MCP relies on it).
> 
> **Updated for `nh` 4.5.0** (installed binary: `nh --version` → `4.5.0`).
> The headline change in 4.5.0 is the **single-elevation model**: local
> `os switch`/`boot`/`test`/`rollback` no longer hand `switch-to-configuration`
> / `nix build` / `ln` steps to the elevation program one at a time. `nh`
> elevates **once** and re-invokes its own content-addressed store path as
> `nh __privileged <JSON op>` with `op ∈ {NixosActivate, NixosRollback}` —
> see §3.5, §4 and `docs/mcp-self-admin.md`.

---

## 1. Toolchain

- Binary: `/run/current-system/sw/bin/nh`.
- Repo: `nix-community/nh` (EUPL-1.2). Stable release ships via Nixpkgs as `nh`;
  this box runs **4.5.0** (`nh --version`). The MCP does **not** pin a version
  — it adapts to whatever `nh` the system provides (the gate recognizes the
  elevation contract by content-addressed store path, not a version string).
- Replaces **both** `nixos-rebuild` and most of `home-manager`'s CLI.
- **It does not cover** raw Nix primitives: `nix eval`, `nix build <drv>`,
  `nix flake update/lock`, `nix develop`, `git`, `sops`. Those still run as
  plain Nix/git/sops in the dev shell (per `AGENTS.md`). The MCP can shell out
  to them separately if needed.

## 2. Global / common flags

| Flag | Meaning |
|---|---|
| `-v / -q` | verbosity |
| `-e/--elevation-strategy <STR>` or `$NH_ELEVATION_STRATEGY` | `auto` \| `none` \| `passwordless` \| `empty-password` \| `program:<PATH>` \| bare PATH. `auto` probes `doas, sudo, run0, pkexec` in order; a PATH (or `program:PATH`) is used **preferentially**, falling back to `auto` only if the program is not on PATH. `empty-password` is for remote `sudo` where PAM authenticates out-of-band (`pam_rssh` + forwarded SSH agent) — nh sends `sudo` an empty stdin password line. **This is the whole security model for an MCP — see §4.** |
| INSTALLABLE positional | `FLAKEREF[#ATTRPATH]` (env `$NH_FLAKE` / `$NH_OS_FLAKE`), or `-f/--file <file> [attr]`, or `-e/--expr <expr> [attr]`, or an absolute path / symlink to a store path. |
| `-- <EXTRA_ARGS>...` | **forwarded verbatim to `nix build`** (so `--no-net`, `--offline`, `--impure`, `--refresh`, `--commit-lock-file`, … are usable). |

## 3. Command map

### 3.1 `nh os <cmd>` (NixOS)

| cmd | What it does | Class | Needs root? | Key flags |
|---|---|---|---|---|
| `info` `[observed]` | List current-system generations (id, date, nver, kernel, confRev, spec, size). **4.5.0:** distinguishes the **running** generation from the **selected boot-default** profile (test-mode / out-of-sync aware); `--json` emits both statuses plus generation metadata | **read** | no | `-P/--profile` (default `/nix/var/nix/profiles/system`), `--fields`, `--json` |
| `build` | Build the system derivation only; **does not activate, does not touch boot** | build-only (safe-ish) | no | `--dry` (**4.5.0:** show what `nix` would build/fetch **without** building; remote hosts unsupported), full nix-build forwarding |
| `switch` | Build + **activate** + set as boot default | **mutating** | **yes** | `-n/--dry` (**4.5.0:** build **only**, no activation — use `dry-activate` for a preview), `-a/--ask`, `-H/--hostname`, `-s/--specialisation`, `--no-validate`, `--continue-on-activation-failure` (**4.5.0**), `--diff auto\|always\|never` |
| `dry-activate` | **4.5.0 (new):** build + preview the activation **without applying** (planned units + diff, nothing started) | preview (safe-ish) | no | `-H/--hostname`, `--no-validate`, `--diff` |
| `boot` | Build + set boot default; **activated on next reboot, not now** | **mutating** | **yes** | same flags as `switch` (incl. `--continue-on-activation-failure`) |
| `test` | Build + activate **transiently** (gone on reboot, doesn't persist boot) | **mutating** (but revertible on reboot) | **yes** | same flags as `switch` |
| `repl` | Load the system attrset into the Nix REPL | read (interactive) | no | — |
| `rollback` | Activate a previous generation | **mutating** (recovery) | **yes** | `-t/--to <GEN>` (default: previous), `-n/--dry`, `-s/-S`, `--no-validate`, `--diff`. **4.5.0:** picks the **predecessor of the selected system profile** (not the running system), restores the selected profile on failure, rejects an explicitly requested specialisation missing from the target generation |
| `build-vm` | Build a VM image | build-only | no | `--run` (**4.5.0:** start the built VM immediately, runs locally), `--with-bootloader/-B`, `--specialisation`; **ignores `--target-host`** (VM runs locally) |
| `build-image` | Build a disk image | build-only | no | `--image-variant` (**4.5.0:** optional — falls back to `config.system.build.isoImage`), `--update`, `--dry` |

Dry-run semantics (`-n` / `--dry`): **changed in 4.5.0.** `--dry` on
`switch`/`boot`/`test` now means **"build only, do not activate"** — it builds
the system and returns without running activation. The **new
`nh os dry-activate`** is the activation preview: it builds and shows the
planned activation (unit start/stop list + diff) **without applying it**, and
under `--elevation-strategy=none` it should not attempt elevation. The MCP's
`os_dryrun` currently drives `nh os switch -n` — that is now a **build-only**
check, not an activation preview, and should be re-pointed at
`dry-activate` (see `docs/mcp-self-admin.md`). `[to-verify]` remaining:
`dry-activate` under strategy `none` on the first real use.

### 3.5 Single-elevation model — `nh __privileged <JSON op>` (4.5.0) `[observed]`

**The headline 4.5.0 change.** Before 4.5.0, a local `os switch`/`rollback`
elevated **each privileged step separately**: the activation program
(`switch-to-configuration`), the `nix build --profile` step, and the `ln`
profile-link each got their own elevation-program invocation. As of 4.5.0,
`nh` elevates **once** for the whole operation and **re-invokes its own
content-addressed store path** as the privileged worker:

```
<store-path>/bin/nh __privileged '{"log_level":...,"op":{<OP>:...}}'
```

where `<OP> ∈ {NixosActivate, NixosRollback}` (op shapes below) and all
privileged steps (`switch-to-configuration` activation,
`nix build --no-link --profile`, `ln -sfn`) run **inside that one elevated
process**. Consequences:

- the elevation strategy is invoked exactly **once**, not per step;
- the target program in the elevation argv is **`nh` itself** (its own store
  path), not `switch-to-configuration`/`nix`/`ln` — the op JSON is the only
  description of what gets activated;
- sudoers rules that granted `NOPASSWD` to individual activation commands
  (`switch-to-configuration`, `nix`, `ln`) **no longer apply** — only the rule
  for the single elevation command (the gate store path, §4) matters.

**Op JSON shapes** (from `nh-core/src/privileged.rs`):

```
"op": { "NixosActivate": {
        "action": "Switch" | "Boot" | "Test" | "DryActivate",
        "switch_to_configuration": "<system>/bin/switch-to-configuration",
        "system": "<store-path>",              # the built system drv
        "continue_on_activation_failure": false,
        "install_bootloader": false,
        "systemd_run": true,                  # systemd 261+: activation in a
                                             # transient service
        "nix_args": [] } }
```

```
"op": { "NixosRollback": {
        "target_profile": "/nix/var/nix/profiles/system-<gen>-link",
        "previous_profile": <profile|null>,  # restored on failure
        "switch_to_configuration": "<target_profile>/bin/switch-to-configuration",
        "systemd_run": true } }
```

**Implication for this deployment:** `nh` invokes the elevation program (the
gate) exactly once as
`nh-admin-gate env <KEY=VAL…> <nh store path> __privileged <JSON op>`; the
gate validates that op JSON **field by field** (and still accepts the legacy
per-step argv forms `switch-to-configuration` / `nix` / `ln` for
defense-in-depth — see §4), then re-execs via `sudo -n` as the single root
worker. That is what commit `186250a` added to `nh-admin-gate.sh`.

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
| `packages <q>` | search.nixos.org (live, network) | `-l/--limit` (def 30), `-c/--channel` (def `nixos-unstable`), `-P/--platforms`, **`--fields <a,b,c>`** (4.5.0: select package fields in normal output) |
| `options <q>` | search.nixos.org (live, network) | same; NixOS + home-manager + nix-darwin options (4.4+ `--scope`), `--fields` |
| `offline --db <PATH> <q>` | **local SPAM DB, no network** | `-D/--db` repeatable (def `$NH_OFFLINE_DB`). **4.5.0:** reads SPAM DB **0.3.0** (single file; the older `# spam-db-v3` format is unreadable). `[to-verify]` a DB must be fetched first (input `nix-index-database` is already in the flake) |
| `prs <q>` | nixpkgs pull requests | **`--title`/`-t`** (4.5.0: match titles only), `--days <D>` (def 15), GH auth via `GH_TOKEN` |
| `issues <q>` | nixpkgs issues (excl. PRs) | **`--title`/`-t`** (4.5.0), `--days <D>` (def 15), GH auth via `GH_TOKEN` |

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
**4.5.0:** `--delete-current` (let the selected profile generation expire
under the normal keep limits — without it the selected generation is always
kept, even after a rollback where it is older than `--keep-since`),
`--cross-filesystems`/`-x` (gcroot scan across mount boundaries),
`--keep-one` (keep all active direnv gcroots regardless of age), and the
gcroot auto-cleanup is now preserved-roots-aware (4.4.1: never deletes a
live, in-use gcroot). An MCP should expose this only behind an explicit
confirmation + keep-at-least-N guard, **never** on the hot path.

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

**Resolution (shipped, S1–S5):** option (2) realized in content-addressed
form — the box runs `security.sudo-rs`, and the single NOPASSWD rule covers
exactly one command: the `nh-admin-gate` store path (option
`andher.security.nhAdminGate.enable`, default `true`, in
`nixos/modules/default/nh-admin-gate.nix`). Mutating `nh` calls from the MCP
go `--elevation-strategy <gate store path>`; on **4.5.0**, `nh` elevates
**once** and re-invokes its own store path as
`nh __privileged <JSON op>` (§3.5), so the gate is invoked as
`nh-admin-gate env <KEY=VAL…> <nh path> __privileged <JSON op>`. The gate
audits and re-validates the **op JSON field by field** (the legacy per-step
argv forms are kept as defense-in-depth) before re-elevating via `sudo -n` as
the single root worker (no other command, no argv can escalate — see
`docs/mcp-self-admin.md`). Read/build tools use
`--elevation-strategy=none` (never prompts), and mutating tools refuse to run
when the gate env is unset — a read-only default.

(Pre-resolution summary, kept for history:) `switch`/`boot`/`test`/
`rollback`/`clean` were **impossible from this MCP without (2)**;
`home switch`, `build`, `info`, `search` work fine without any of the above —
still true today for everything the gate does not cover.

## 5. Remote deployments `[observed flags]`

- `--target-host <H>` — build here, **activate on host H over SSH**.
  **4.5.0:** sets the remote system profile with **`nix-env --set`** (as
  nixos-rebuild does) instead of `nix build --profile`; activation logs
  stream per step; a wrong sudo password is retried up to three times.
- `--build-host <H>` — build on H, activate locally (or paired with target).
  **4.5.0:** uses `ssh-ng://` (the legacy `ssh://` store scheme is removed);
  no longer copies the result when it is already in the local store, and
  with a different target copies straight to the host that activates (a
  local out-link is created only if it reaches the local store).
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
| `os_dryrun` | `nh os switch -n …` (**4.5.0:** build-only; **`dry-activate`** is the activation preview) | dry (read-ish) | `[to-verify]` |
| `os_switch` | `nh os switch` | **mutating** | yes |
| `os_boot` | `nh os boot` | **mutating** | yes |
| `os_test` | `nh os test` | **mutating** (reversible) | yes |
| `os_rollback` | `nh os rollback -t GEN` | **mutating** (recovery) | yes |
| `home_switch` | `nh home switch` | mutating (user) | no |
| `search_pkgs` / `search_options` | `nh search …` | read | no |

Implemented as of `self-admin-mcp` (see `docs/mcp-self-admin.md`):
`os_status`, `os_generations`, `os_build`, `os_dryrun`, `search_packages`,
`search_options` are the live read/build-only surface; `os_switch` and
`os_rollback` are shipped but **gated** (mutating — host allowlisted,
`confirm: true`, gate binary required); `os_boot`, `os_test`, `home_switch`,
and all `clean` commands are **deliberately not exposed**.

**4.5.0 note:** the live mechanism behind `os_switch`/`os_rollback` is now
the single-elevation model (§3.5) — `nh` elevates once via the gate and
re-runs `nh __privileged <JSON op>` as the root worker; the gate validates
that op JSON. And `os_dryrun` should map to `nh os dry-activate` for a true
activation preview (4.5.0 `switch --dry` only builds — see
`docs/mcp-self-admin.md`).

## 7. Environment / wiring facts for the OpenCode config

- `cwd` must be the flake dir (`/home/anderer/flake`) so `nh os switch .`
  resolves `.#amateur`.
- `NH_FLAKE=` / `NH_OS_FLAKE=` env can pin the installable explicitly.
- `NH_ELEVATION_STRATEGY=` env controls elevation per-process (overrides
  `-e`); values: `auto` / `none` / `passwordless` / `empty-password` /
  `program:<PATH>` (bare PATH = prefer that program, fall back to `auto`).
- `NH_OFFLINE_DB=` sets the SPAM DB path (colon-separated list) for
  `search offline`.
- 4.5.0 env additions relevant to this deployment: `NH_PRESERVE_ENV`
  (which env vars are forwarded to elevated commands — on by default, `"0"`
  to disable), `NH_NO_SYSTEMD_RUN` (`0`/`1`/`true`/`false`/`yes`/`no`; disable
  the systemd-261 transient-service activation wrapper),
  `NH_CONTINUE_ON_ACTIVATION_FAILURE` (add the generation to the bootloader
  even if activation fails), `NH_ROM` / `NH_ROM_LOG` (build-progress display;
  `NH_NOM` is the deprecated alias, removed in 5.0), `NH_ASK` (`1/true/yes`
  = `--ask`). Note: **boolean `NH_*` env vars are strict** in 4.5.0 — only
  `1/true/yes/0/false/no` are accepted (`on`/`off` work only for `NH_ROM`).
