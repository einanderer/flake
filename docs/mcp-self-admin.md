# self-admin-mcp — Local NixOS Self-Administration

MCP stdio server that lets the agent administer the local NixOS flake through
`nh` (nix-community/nh; replaces `nixos-rebuild` for this repo): read-only
state, build-only checks, a dry-run preview, and — strictly gated — mutating
`switch`/`rollback`.

Companion reading: `docs/nh-cli-map.md` (what `nh` can do, read vs
mutating classes).

**4.5.0 note:** since `nh` 4.5.0, mutating tools no longer hand individual
`switch-to-configuration`/`nix build`/`ln` steps to the elevation program —
`nh` elevates **once** per mutation and re-invokes its own content-addressed
store path as `nh __privileged <JSON op>` (op ∈ {NixosActivate,
NixosRollback}); the gate validates that op JSON field by field before
re-elevating via `sudo -n` (see §Security model). And `os_dryrun` is
currently pointed at `nh os switch -n`, which in 4.5.0 is **build-only** —
`nh os dry-activate` is the activation preview; re-pointing is the next
refactor step.

## Build & wiring

- Source: `static/self-admin-mcp/src/main.py` (single file; stdio MCP server
  driven by plain `subprocess`, no venv).
- Build rule: `pkgs/by-name/self-admin-mcp.nix`. The generated
  `bin/self-admin-mcp` wrapper mirrors the python `mcp` package bootstrap
  (shebang+coding lines, then one `addsitedir` line, then the entry point
  `import main; main.main()`) so `mcp.server` resolves without a venv — same
  pattern as `ddg-mcp`/`whisper-mcp` (see `docs/ai.md`).
- **Stable install (GC-proof)**: the NixOS module
  `nixos/modules/default/self-admin-mcp.nix` (option
  `andher.mcp.selfAdminMcp.enable`, default `true`) puts the package into
  `environment.systemPackages`, so the binary lives at
  `/run/current-system/sw/bin/self-admin-mcp` — the same mechanism as
  `nh-admin-gate` (`nixos/modules/default/nh-admin-gate.nix`). Harness
  configs reference that stable path, never a volatile `/nix/store` path,
  so flake rebuilds can't leave the MCP server pointing at a GC'd
  derivation.
- Harness wiring (kept **locally, outside this git repo**) —
  opencode: `~/.config/opencode/opencode.jsonc`, Pi:
  `~/.pi/agent/mcp.json`. Both carry the same server with
  `NH_ADMIN_REMOTE_HOSTS` empty (local-only; see
  "Remote operation" below):

  ```jsonc
  {
    "mcp": {
      "servers": {
        "self-admin": {
          "type": "local",
          "command": [ "/run/current-system/sw/bin/self-admin-mcp" ],
          "environment": {
            "NH_ADMIN_FLAKE_DIR": "/home/anderer/flake",
            "NH_ADMIN_LOCAL_HOSTS": "amateur",
            "NH_ADMIN_REMOTE_HOSTS": "",
            "NH_ADMIN_GATE": "/run/current-system/sw/bin/nh-admin-gate"
          }
        }
      }
    }
  }
  ```

  `command` and `NH_ADMIN_GATE` are **stable system paths**: a flake
  rebuild that changes either package needs **no config edits** — the next
  `nh os switch` delivers the new binary under the same path, and GC can
  never break the link. One-time transition note: until the first switch
  that activates the install module has run, the stable path does not
  exist yet — keep a freshly built `/nix/store/...` path in both configs
  until that switch, then swap to the stable path.

## Environment configuration

All config is env-driven; empty defaults make the server read-only.

| Variable | Meaning | Default |
| :--- | :--- | :--- |
| `NH_ADMIN_FLAKE_DIR` | flake dir; `cwd` for every `nh` call | `/home/anderer/flake` |
| `NH_ADMIN_LOCAL_HOSTS` | hosts switchable **without** `--target-host` (this box) | `""` → no switch possible |
| `NH_ADMIN_REMOTE_HOSTS` | hosts switchable with `--target-host <host>` | `""` |
| `NH_ADMIN_GATE` | gate binary path (stable: `/run/current-system/sw/bin/nh-admin-gate`); mutating tools **refuse** when unset or not executable (no fallback) | `""` → read-only server |
| `NH_ADMIN_NH_BIN` | the `nh` binary | `/run/current-system/sw/bin/nh` |

Every host argument of every tool is classified against the two allowlists;
anything else is rejected inside the server before `nh` is ever spawned.

## Tool surface

| Tool | Class | nh call | Params |
| :--- | :--- | :--- | :--- |
| `os_status` | read | `nh os info --elevation-strategy=none` + `git status` | — |
| `os_generations` | read | `nh os info` | `limit` (10, max 50) |
| `os_build` | build-only (no activation, no root) | `nh os build .#<host> --elevation-strategy=none` | `hostname` (empty = local) |
| `os_dryrun` | dry-run | `nh os switch -n .#<host> --elevation-strategy=none` (**4.5.0:** build-only, no activation — `dry-activate` is the activation preview; re-point pending) | `hostname` |
| `search_packages` | read | `nh search packages <query>` | `query`, `limit` (15, max 50) |
| `search_options` | read | `nh search options <query>` | `query`, `limit` (15, max 50) |
| `os_switch` | **mutating** | `nh os switch .#<host> --elevation-strategy <gate>` | `hostname`, `confirm: bool` |
| `os_rollback` | **mutating** (recovery) | `nh os rollback -t <GEN> --elevation-strategy <gate>` | `hostname`, `generation` (0 = previous), `confirm: bool` |

Mutating tools require **all three**: allowlisted host, `confirm: true`, and a
set+executable `NH_ADMIN_GATE` — and `nh` is invoked with
`--elevation-strategy <gate store path>`, so any mutation rides layer 3 below.
Under 4.5.0 that means a **single** elevation invocation per mutation
(`nh __privileged <JSON op>`, not one per step). Run `os_dryrun` before
`os_switch` — for a true activation preview use `dry-activate` (4.5.0
`switch -n` only builds).

## Remote operation (unused since 2026-11-06 — user-shell deploy)

The server code still supports allowlisted remote hosts
(`--target-host <host>`), but in this deployment
`NH_ADMIN_REMOTE_HOSTS` is intentionally empty in both harness
configs (as of 2026-11-06 — decision: simplest robust route, the
MCP stdio client has no TTY for the prompts, so it can't drive
them):

- When a remote host IS allowlisted, remote mutation rides the gate:
  the server probes `ssh -o BatchMode=yes <host> test -x
  /run/current-system/sw/bin/nh-admin-gate`, then `nh` runs with the
  remote gate path as `--elevation-strategy`; the remote gate
  (identical build, installed by the same machine module, same
  `NOPASSWD` sudoers shape) re-execs itself via `sudo -n` —
  no TTY, no password prompt end-to-end. This only works with
  **key-based** ssh. When the probe fails (password-login ssh, host
  unreachable, gate not deployed), the server falls back to `auto`;
  `nh` then picks doas/sudo/run0/pkexec remotely, which can prompt —
  and behind stdio the run hangs at the remote end instead.
- Read-only remote checks stay with the agent, outside MCP:
  `nh os build .#<host>` (strategy `none`; `machines/` builds
  locally — no ssh, no gate, no remote prompts).
- Remote `os switch`/`os rollback` is executed by the user in an
  interactive shell: `nh os switch .#<host> --target-host <host> -n`
  first (dry-run), then without `-n`.

## Security model (three layers)

1. **Env allowlists** (empty by default) — host validation in the server;
   nothing else reaches `nh`.
2. **`confirm: true`** — model-visible second ring on mutating tools.
3. **OS-level gate** (`nh-admin-gate`) — the outermost layer; see below.

### `nh-admin-gate`

- Build: `pkgs/by-name/nh-admin-gate.nix`; the bash source is
  `static/self-admin-gate/nh-admin-gate.sh` (plain shell, no nix-string
  escaping — store paths injected via `@BASH@`/`@NIX@`/`@LN@`/`@JQ@`/`@ENV@`).
- Activation: option `andher.security.nhAdminGate.enable` (default `true`) in
  `nixos/modules/default/nh-admin-gate.nix` installs a single
  `security.sudo-rs.extraRules` entry: user `anderer`, host `ALL`, option
  `NOPASSWD`, command = **exactly the gate's store path** — no other command,
  no arguments. That store path is the only privilege the gate can ever
  receive.
- Runtime: **4.5.0 contract (current)** — `nh` elevates once per mutation
  and invokes the gate as
  `nh-admin-gate env USER=… LOCALE_ARCHIVE=… PATH=… NIX_PATH=… <nh store path>
  __privileged <JSON op>`, where the op is `{NixosActivate:{action:"Switch",
  switch_to_configuration, system, continue_on_activation_failure:false,
  install_bootloader:false, systemd_run, nix_args:[]}}` or
  `{NixosRollback:{target_profile, previous_profile, switch_to_configuration,
  systemd_run}}`. The gate validates the **op JSON field by field** (op
  name, action = `Switch` only, `install_bootloader`/
  `continue_on_activation_failure` must be `false`, empty `nix_args`, exact
  `switch_to_configuration` = `<system>/bin/switch-to-configuration` or
  `<target_profile>/bin/switch-to-configuration`, target profiles must be
  real `/nix/var/nix/profiles/system-<gen>-link` symlinks) — and then re-runs
  the derivation check: only a `nixos-system-<this host>` derivation can ever
  be activated here. (The old per-step argv forms —
  `<SYSTEM>/bin/switch-to-configuration <sub>`, `nix build --no-link --profile
  /nix/var/nix/profiles/system <drv>`, `ln -sfn <profile> /nix/var/nix/profiles/system`
  — are still accepted and validated for defense-in-depth, in case an older
  `nh` version is ever reinstalled.)
- Runtime: the env-prefix argv before the program is re-validated
  (allowlist `USER|LOCALE_ARCHIVE|PATH|NIX_PATH|HOME|TMPDIR`); the gate
  re-executes itself via `sudo -n` (non-interactive; no fallback to a
  non-elevated run, which is also the server's policy) and, as root, execs
  the validated command byte-exact.

Neither a wrong/compromised argv nor a foreign `nixos-system-*` derivation can
escalate through it. Verified in S4 (2026-10-30): 5/5 reject tests all exit
1 **before** the sudo re-exec.

## Deliberately NOT exposed

- `nh clean *` — destructive store GC; never on the MCP hot path.
- `nh os boot` / `nh os test` — activation paths not needed for this setup;
  `rollback` is the recovery path that IS exposed.
- `nh home *` — this flake has no standalone `homeConfigurations` (home
  manager lives inside the OS config); `nh home switch` would be a no-op.
- Any remote target: `NH_ADMIN_REMOTE_HOSTS` is empty in this deployment
  — see the "Remote operation" section above.
