"""self-admin-mcp — MCP stdio server for self-administering the local NixOS
flake through `nh` (nix-community/nh, replaces `nixos-rebuild` for this repo).

Tool surface (see docs/mcp-self-admin.md for the full contract):

  read:
    os_status          current vs latest generation, git state, hosts, gate
    os_generations     `nh os info` (system generations)
    search_packages    `nh search packages`  (read-only registry search)
    search_options     `nh search options`   (read-only option search)
  build-only (no activation, no boot entry, no root):
    os_build           `nh os build .#<host>`
    os_dryrun          `nh os switch -n .#<host>` (action preview, [to-verify]
                       that -n never elevates; fails cleanly when it must)
  mutating (require `confirm: true` AND the elevated gate path to be set):
    os_switch          `nh os switch .#<host>` via elevation strategy = gate
    os_rollback        `nh os rollback [-t GEN]` via elevation strategy = gate

Security model (three independent layers, this is the OUTERMOST one only):
  1. Env allowlists (empty by default):
       NH_ADMIN_FLAKE_DIR   flake directory (cwd for all `nh` calls)
       NH_ADMIN_LOCAL_HOSTS hosts switchable WITHOUT --target-host (this box)
       NH_ADMIN_REMOTE_HOSTS hosts switchable WITH --target-host <host>
     Every host argument is validated against these; nothing else reaches nh.
  2. `confirm: true` is mandatory on mutating tools (model-visible 2nd ring).
  3. OS-level: mutating runs only through an elevation strategy that is a
     content-addressed gate binary (sudoers NOPASSWD rule); the gate re-validates
     host/scope itself, so a compromised/wrong argv still cannot escalate.
     `NH_ADMIN_GATE` names that binary; when unset, mutating tools refuse.

Deliberately NOT exposed: `nh clean *` (destructive store cleanup),
`nh os boot`, `nh os test`, `nh home *` (this flake has no standalone
homeConfigurations — home manager lives inside the OS config), and any
remote target not in NH_ADMIN_REMOTE_HOSTS.
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# config (all env-driven, empty defaults = read-only server)
# ---------------------------------------------------------------------------

FLAKE_DIR = os.environ.get("NH_ADMIN_FLAKE_DIR", "/home/anderer/flake")
LOCAL_HOSTS = os.environ.get("NH_ADMIN_LOCAL_HOSTS", "")
REMOTE_HOSTS = os.environ.get("NH_ADMIN_REMOTE_HOSTS", "")
GATE = os.environ.get("NH_ADMIN_GATE", "")

NH_BIN = os.environ.get("NH_ADMIN_NH_BIN", "/run/current-system/sw/bin/nh")

# Env hygiene for the launched `nh`:
#   `nh` is a Go binary that FORWARDS its own process env into the
#   elevation-strategy argv (nh os switch/rollback). The gate validates
#   every KEY=val in that argv against a strict allowlist — see
#   nh-admin-gate.sh (env-key allowlist at the L58-62 case). Any key OUTSIDE
#   that allowlist makes the gate REJECT the whole invocation (fail-closed,
#   correct behavior).
#   This module is driven by opencode and inherits NH_ADMIN_*, PWD, USER,
#   SHELL, TERM, SHLVL, XDG_*, HOME, PATH, NIX_PATH (…). If we launched `nh`
#   with the full env, the gate would see NH_ADMIN_*, PWD, TERM, … and
#   reject (T2c attempt #1: REJECT: disallowed env key 'NH_ADMIN_LOCAL_HOSTS').
#   Hand `nh` ONLY the gate-allowlisted keys. The resulting env is a SUBSET of
#   the allowlist, so whatever nh forwards is already inside it. This keeps
#   the gate's own fail-closed allowlist as the single source of truth — we
#   don't loosen it, we just make our nh clean.
_NH_ENV_KEYS: tuple[str, ...] = (
    "USER", "LOCALE_ARCHIVE", "PATH", "NIX_PATH", "HOME", "TMPDIR",
)


def _nh_env() -> dict[str, str]:
    """Curated env for the launched `nh`: exactly the gate-allowlisted keys.

    Any other key (NH_ADMIN_*, PWD, SHELL, TERM, SHLVL, XDG_*, …) is stripped.
    The values come from THIS process (opencode server), so we see what nh
    sees. If a key is missing from the server env, it is simply absent (nh
    inherits the normal user-env contract of `nix`).
    """
    return {k: os.environ[k] for k in _NH_ENV_KEYS if k in os.environ}


OUT_LIMIT = 12000  # truncate tool output so agent context stays usable

TIMEOUTS = {
    "info": 60,
    "build": 3600,
    "dry": 900,
    "search": 120,
    "switch": 1800,
    "rollback": 600,
    "status": 30,
}


def _default_host() -> str:
    try:
        return socket.gethostname()
    except OSError:
        return ""


def _log_err(msg: str) -> None:
    sys.stderr.write(f"[self-admin-mcp] {msg}\n")


# ---------------------------------------------------------------------------
# validation
# ---------------------------------------------------------------------------


def _classify_host(host: str) -> tuple[str | None, str | None]:
    """Return (kind, error). kind in {"local", "remote", None}."""
    if not host:
        host = _default_host()
    if host == _default_host():
        if host in LOCAL_HOSTS:
            return "local", None
        return None, (
            f"local host {host!r} not in NH_ADMIN_LOCAL_HOSTS {LOCAL_HOSTS!r}; "
            "reconfigure the server env before switching"
        )
    if host in REMOTE_HOSTS:
        return "remote", None
    return None, (
        f"host {host!r} not allowed. local allowlist={LOCAL_HOSTS!r} "
        f"remote allowlist={REMOTE_HOSTS!r} (env NH_ADMIN_LOCAL_HOSTS / "
        "NH_ADMIN_REMOTE_HOSTS)"
    )


def _run(args: list[str], timeout: int, cwd: str | None = None) -> dict:
    """Run a command; return a result envelope (never raises)."""
    started = time.monotonic()
    try:
        proc = subprocess.run(
            args,
            cwd=cwd or FLAKE_DIR,
            capture_output=True,
            text=True,
            timeout=timeout,
            # Launch `nh` with a CURATED env (only the gate-allowlisted keys);
            # see _nh_env() above. Full MCP-process env would leak NH_ADMIN_*,
            # PWD, SHELL, TERM, SHLVL, XDG_* into nh and thus into the gate
            # argv — REJECTing the switch (fail-closed, but blocks real ops).
            env=_nh_env(),
        )
        rc, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "error": f"timed out after {timeout}s",
            "cmd": " ".join(args),
        }
    except OSError as e:
        return {"ok": False, "error": str(e), "cmd": " ".join(args)}

    duration = time.monotonic() - started
    out = {
        "cmd": " ".join(args),
        "rc": rc,
        "ok": rc == 0,
        "duration_s": round(duration, 2),
        "stdout": stdout[:OUT_LIMIT],
        "stderr": stderr[:OUT_LIMIT],
    }
    if len(stdout) > OUT_LIMIT or len(stderr) > OUT_LIMIT:
        out["truncated"] = True
    return out


# ---------------------------------------------------------------------------
# tool implementations
# ---------------------------------------------------------------------------


def _t_os_status() -> dict:
    """Read: current vs latest system generation + repo state + gate state."""
    result = {
        "host": _default_host(),
        "flake_dir": FLAKE_DIR,
        "local_allowlist": LOCAL_HOSTS,
        "remote_allowlist": REMOTE_HOSTS,
        "gate": GATE or "(unset — mutating tools disabled)",
        "gate_ok": bool(GATE) and os.access(GATE, os.X_OK),
    }
    info = _run(
        [NH_BIN, "os", "info", "--elevation-strategy=none"],
        TIMEOUTS["status"],
    )
    if info["ok"]:
        lines = info["stdout"].strip().splitlines()
        # `nh os info` prints a TWO-line header (a "NixOS <version>" banner on
        # line 1 + a "Generation No …" column header on line 2) and then one
        # row per generation, sorted newest-first. Only rows whose first field
        # is a digit are data, so scan all of them instead of assuming a
        # single header line (the old `lines[1:]` assumed one header, which
        # left rows[0] on the column header and yielded current=None).
        gens = []
        current = None
        for ln in lines:
            parts = ln.split()
            if len(parts) >= 2 and parts[0].isdigit():
                gens.append(int(parts[0]))
                if parts[1] == "(current)":
                    current = int(parts[0])
        result["current_system_generation"] = current
        result["latest_generation"] = max(gens) if gens else None
    else:
        result["generation_error"] = info["stderr"][:500]
    git = _run(
        [
            "git",
            "-C",
            FLAKE_DIR,
            "status",
            "--porcelain",
            "--branch",
        ],
        TIMEOUTS["status"],
    )
    if git["ok"]:
        git_lines = git["stdout"].strip().splitlines()
        branch = git_lines[0] if git_lines else ""
        result["git_branch"] = branch.removeprefix("## ").split(" ")[0]
        result["git_dirty_files"] = len(git_lines) - 1
    return result


def _t_os_generations(limit: int = 10) -> dict:
    """Read: system generations (`nh os info`)."""
    limit = max(1, min(int(limit or 10), 50))
    args = [NH_BIN, "os", "info", "--elevation-strategy=none"]
    r = _run(args, TIMEOUTS["info"])
    if r["ok"]:
        lines = r["stdout"].splitlines()
        head, rows = (lines[0] if lines else ""), lines[1:]
        r["stdout"] = "\n".join([head, *rows[:limit]])
    return r


def _t_os_build(hostname: str = "") -> dict:
    """Build-only: compiles the system derivation, touches nothing (no root)."""
    kind, err = _classify_host(hostname)
    if err:
        return {"ok": False, "error": err}
    host = hostname or _default_host()
    args = [NH_BIN, "os", "build", f".#{host}", "--elevation-strategy=none"]
    if kind == "remote":
        args += ["--target-host", host]
    r = _run(args, TIMEOUTS["build"])
    r["class"] = "build-only"
    return r


def _t_os_dryrun(hostname: str = "") -> dict:
    """Dry run: `nh os switch -n` — preview actions without activating.

    [to-verify] whether -n ever elevates; with strategy `none` it either works
    as a pure preview (expected) or errors cleanly (visible to the caller).
    """
    kind, err = _classify_host(hostname)
    if err:
        return {"ok": False, "error": err}
    host = hostname or _default_host()
    args = [
        NH_BIN,
        "os",
        "switch",
        f".#{host}",
        "--dry",
        "--elevation-strategy=none",
    ]
    if kind == "remote":
        args += ["--target-host", host]
    r = _run(args, TIMEOUTS["dry"])
    r["class"] = "dry-run"
    return r


def _t_search_packages(query: str, limit: int = 15) -> dict:
    """Read: live package search (search.nixos.org) via `nh search packages`."""
    limit = max(1, min(int(limit or 15), 50))
    r = _run(
        [NH_BIN, "search", "packages", query, "--limit", str(limit)],
        TIMEOUTS["search"],
    )
    r["class"] = "read"
    return r


def _t_search_options(query: str, limit: int = 15) -> dict:
    """Read: live option search (NixOS + home-manager) via `nh search options`."""
    limit = max(1, min(int(limit or 15), 50))
    r = _run(
        [NH_BIN, "search", "options", query, "--limit", str(limit)],
        TIMEOUTS["search"],
    )
    r["class"] = "read"
    return r


def _os_mutate(mode: str, hostname: str, confirm: bool, generation: int = 0) -> dict:
    """Shared path for os_switch / os_rollback.

    mode in {"switch", "rollback"}. Both REQUIRE:
      - allowlisted host
      - confirm=True
      - NH_ADMIN_GATE set + executable (else refusal, do NOT fall back)
    """
    kind, err = _classify_host(hostname)
    if err:
        return {"ok": False, "error": err}
    host = hostname or _default_host()
    if not confirm:
        return {
            "ok": False,
            "error": "confirm=true required for this mutating operation; "
            "show the user the dry-run (os_dryrun) first",
        }
    if not GATE or not os.access(GATE, os.X_OK):
        return {
            "ok": False,
            "error": (
                "NH_ADMIN_GATE unset or not executable — this environment is "
                "configured read-only. No fallback to non-elevated mutation."
            ),
        }

    i_generation = int(generation or 0)
    if i_generation < 0:
        return {"ok": False, "error": "generation must be >= 0"}

    common = ["--elevation-strategy", GATE]
    if mode == "switch":
        args = [NH_BIN, "os", "switch", f".#{host}", *common]
        timeout = TIMEOUTS["switch"]
    else:  # rollback
        if i_generation > 0:
            common = common + ["-t", str(i_generation)]
        args = [NH_BIN, "os", "rollback", *common]
        timeout = TIMEOUTS["rollback"]
    if kind == "remote":
        args += ["--target-host", host]

    r = _run(args, timeout)
    r["class"] = "mutating"
    r["host"] = host
    return r


# ---------------------------------------------------------------------------
# server
# ---------------------------------------------------------------------------


def main() -> None:
    from mcp.server.mcpserver import MCPServer

    _log_err(f"imported mcp.server.mcpserver.MCPServer (host={_default_host()!r})")
    server = MCPServer("self-admin-mcp")

    @server.tool(
        name="os_status",
        title="NixOS flake self-admin status",
        description=(
            "Read-only status of the local NixOS flake: current vs latest "
            "system generation, git branch/dirty state, and which "
            "hosts/mutations this server may perform (allowlists + gate). "
            "Call this FIRST in a self-admin task."
        ),
    )
    def tool_os_status() -> dict:
        return _t_os_status()

    @server.tool(
        name="os_generations",
        title="List system generations",
        description="Read-only `nh os info`: system generations with dates, kernel and config revision.",
    )
    def tool_os_generations(limit: int = 10) -> dict:
        return _t_os_generations(limit)

    @server.tool(
        name="os_build",
        title="Build the system configuration (no activation)",
        description=(
            "Build-only: compiles the system derivation for the given host. "
            "Does NOT activate, does NOT touch the boot entry, needs no root. "
            "Safe to run any time; good as an evaluation check before os_switch."
        ),
    )
    def tool_os_build(hostname: str = "") -> dict:
        return _t_os_build(hostname)

    @server.tool(
        name="os_dryrun",
        title="Dry run of os switch (preview actions)",
        description=(
            "Runs `nh os switch -n` — prints the planned unit start/stop "
            "actions WITHOUT applying. Read-ish; if it cannot run without "
            "elevation it fails cleanly instead of mutating."
        ),
    )
    def tool_os_dryrun(hostname: str = "") -> dict:
        return _t_os_dryrun(hostname)

    @server.tool(
        name="search_packages",
        title="Search NixOS packages (read-only)",
        description=(
            "Live package search against search.nixos.org (network). "
            "Use for hallucination-proof package discovery."
        ),
    )
    def tool_search_packages(query: str, limit: int = 15) -> dict:
        return _t_search_packages(query, limit)

    @server.tool(
        name="search_options",
        title="Search NixOS / home-manager options (read-only)",
        description=(
            "Live option search (NixOS + home-manager) against search.nixos.org. "
            "Use before touching a NixOS option path."
        ),
    )
    def tool_search_options(query: str, limit: int = 15) -> dict:
        return _t_search_options(query, limit)

    @server.tool(
        name="os_switch",
        title="Switch the NixOS configuration (MUTATING)",
        description=(
            "MUTATING: builds + activates the flake for the given host and "
            "sets the boot default. Requires confirm=true, an allowlisted "
            "host, and the elevated gate to be configured. ALWAYS run os_dryrun "
            "first and show its output to the user."
        ),
    )
    def tool_os_switch(hostname: str = "", confirm: bool = False) -> dict:
        return _os_mutate("switch", hostname, confirm)

    @server.tool(
        name="os_rollback",
        title="Roll back to a previous generation (MUTATING)",
        description=(
            "MUTATING (recovery path): activates a previous system generation. "
            "generation=0 means 'previous'. Requires confirm=true, allowlisted "
            "host, and the elevated gate. Use os_generations to pick a target."
        ),
    )
    def tool_os_rollback(hostname: str = "", generation: int = 0, confirm: bool = False) -> dict:
        return _os_mutate("rollback", hostname, confirm, generation)

    _log_err("self-admin-mcp ready (stdio)")
    server.run(transport="stdio")


if __name__ == "__main__":
    main()
