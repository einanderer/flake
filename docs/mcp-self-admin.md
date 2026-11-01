# self-admin-mcp — Local NixOS Self-Administration

MCP stdio server that lets the agent administer the local NixOS flake through
`nh` (nix-community/nh; replaces `nixos-rebuild` for this repo): read-only
state, build-only checks, a dry-run preview, and — strictly gated — mutating
`switch`/`rollback`.

Companion reading: `docs/nh-cli-map.md` (what `nh` 4.4.2 can do, read vs
mutating classes).

## Build & wiring

- Source: `static/self-admin-mcp/src/main.py` (single file; stdio MCP server
  driven by plain `subprocess`, no venv).
- Build rule: `pkgs/by-name/self-admin-mcp.nix`. The generated
  `bin/self-admin-mcp` wrapper mirrors the python `mcp` package bootstrap
  (shebang+coding lines, then one `addsitedir` line, then the entry point
  `import main; main.main()`) so `mcp.server` resolves without a venv — same
  pattern as `ddg-mcp`/`whisper-mcp` (see `docs/ai.md`).
- opencode wiring (kept **locally, outside this git repo**) —
  `~/.config/opencode/opencode.jsonc`:

  ```jsonc
  {
    "mcp": {
      "servers": {
        "self-admin": {
          "type": "local",
          "command": [ "<store-path>/bin/self-admin-mcp" ],
          "environment": {
            "NH_ADMIN_FLAKE_DIR": "/home/anderer/flake",
            "NH_ADMIN_LOCAL_HOSTS": "amateur",
            "NH_ADMIN_REMOTE_HOSTS": "",
            "NH_ADMIN_GATE": "<gate store path>/bin/nh-admin-gate"
          }
        }
      }
    }
  }
  ```

  Both the `command` entry and `NH_ADMIN_GATE` are **store paths**: after
  flake changes that rebuild either package, the paths in `opencode.jsonc`
  must be re-derived and the entry updated (no git commit involved — the
  config lives in the user's home).

## Environment configuration

All config is env-driven; empty defaults make the server read-only.

| Variable | Meaning | Default |
| :--- | :--- | :--- |
| `NH_ADMIN_FLAKE_DIR` | flake dir; `cwd` for every `nh` call | `/home/anderer/flake` |
| `NH_ADMIN_LOCAL_HOSTS` | hosts switchable **without** `--target-host` (this box) | `""` → no switch possible |
| `NH_ADMIN_REMOTE_HOSTS` | hosts switchable with `--target-host <host>` | `""` |
| `NH_ADMIN_GATE` | store path of the gate binary; mutating tools **refuse** when unset or not executable (no fallback) | `""` → read-only server |
| `NH_ADMIN_NH_BIN` | the `nh` binary | `/run/current-system/sw/bin/nh` |

Every host argument of every tool is classified against the two allowlists;
anything else is rejected inside the server before `nh` is ever spawned.

## Tool surface

| Tool | Class | nh call | Params |
| :--- | :--- | :--- | :--- |
| `os_status` | read | `nh os info --elevation-strategy=none` + `git status` | — |
| `os_generations` | read | `nh os info` | `limit` (10, max 50) |
| `os_build` | build-only (no activation, no root) | `nh os build .#<host> --elevation-strategy=none` | `hostname` (empty = local) |
| `os_dryrun` | dry-run preview | `nh os switch -n .#<host> --elevation-strategy=none` | `hostname` |
| `search_packages` | read | `nh search packages <query>` | `query`, `limit` (15, max 50) |
| `search_options` | read | `nh search options <query>` | `query`, `limit` (15, max 50) |
| `os_switch` | **mutating** | `nh os switch .#<host> --elevation-strategy <gate>` | `hostname`, `confirm: bool` |
| `os_rollback` | **mutating** (recovery) | `nh os rollback -t <GEN> --elevation-strategy <gate>` | `hostname`, `generation` (0 = previous), `confirm: bool` |

Mutating tools require **all three**: allowlisted host, `confirm: true`, and a
set+executable `NH_ADMIN_GATE` — and `nh` is invoked with
`--elevation-strategy <gate store path>`, so any mutation rides layer 3 below.
Run `os_dryrun` before `os_switch`.

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
- Runtime: nh invokes the gate as
  `nh-admin-gate env USER=… LOCALE_ARCHIVE=… PATH=… NIX_PATH=… <prog> <args…>`.
  The gate:
  - re-validates the **entire argv** itself: env keys restricted to
    `USER|LOCALE_ARCHIVE|PATH|NIX_PATH|HOME|TMPDIR`; program restricted to
    `<SYSTEM>/bin/switch-to-configuration` (subs
    `test|switch|dry-activate|activate|rollback|boot`), bare `nix`, bare `ln`;
    per-program argv pinned to exactly
    `nix build --no-link --profile /nix/var/nix/profiles/system <drv-output>` /
    `ln -sfn <src> /nix/var/nix/profiles/system` with `<src>` matching
    `/nix/var/nix/profiles/system-*`;
  - re-verifies the target derivation: `nix derivation show <path>` must
    resolve to `nixos-system-<this host>` — only this machine's own system
    can ever be activated;
  - re-execs itself via `sudo -n` (non-interactive; no fallback to a
    non-elevated run, which is also the server's policy);
  - only then execs the command, byte-exact, as root.

Neither a wrong/compromised argv nor a foreign `nixos-system-*` derivation can
escalate through it. Verified in S4 (2026-10-30): 5/5 reject tests all exit
1 **before** the sudo re-exec.

## Deliberately NOT exposed

- `nh clean *` — destructive store GC; never on the MCP hot path.
- `nh os boot` / `nh os test` — activation paths not needed for this setup;
  `rollback` is the recovery path that IS exposed.
- `nh home *` — this flake has no standalone `homeConfigurations` (home
  manager lives inside the OS config); `nh home switch` would be a no-op.
- Any remote target not in `NH_ADMIN_REMOTE_HOSTS` (currently empty).
