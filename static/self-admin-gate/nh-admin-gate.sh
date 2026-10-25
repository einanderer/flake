#!@BASH@/bin/bash
# nh-admin-gate — OS-level gate for `nh` self-admin mutations (layer 3 of the
# MCP self-admin security; see docs/mcp-self-admin.md).
#
# The MCP server drives nh as:
#     nh os switch .#<host> --elevation-strategy <this binary's store path>
# nh then invokes THIS script (as the unprivileged user) as
#     nh-admin-gate env USER=... LOCALE_ARCHIVE=... PATH=... NIX_PATH=...
#         <SYSTEM>/bin/switch-to-configuration <test|switch|dry-activate|activate|rollback>
# where <SYSTEM> is the built nixos-system-<host>-... store path.
#
# The gate audits + validates every part of that argv, re-executes itself via
# `sudo -n` (a single NOPASSWD sudoers rule for exactly this store path is the
# only privilege it ever receives), and as root execs the activation command
# exactly — so neither a model- or MCP-crafted argv nor an out-of-allowlist
# system derivation can ever be activated on this host.
set -euo pipefail

NIX=@NIX@/bin/nix
JQ=@JQ@/bin/jq
ENV=@ENV@/bin/env
SUDO=/run/wrappers/bin/sudo

HOST="$(hostname)"
AUDIT() { printf '[nh-admin-gate] %s\n' "$*" >&2; }

[ "$#" -ge 3 ] || { AUDIT "REJECT: too few arguments"; exit 1; }
[ "$1" = "env" ] || { AUDIT "REJECT: argv[1]='$1' != 'env'"; exit 1; }

# --- split: env KEY=VALUE... <prog> <args...> --------------------------------
shift
ASGS=()
prog=""
ARGS=()
for a in "$@"; do
  if [ -z "$prog" ]; then
    if [[ "$a" == *"="* && "${a%%=*}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      ASGS+=("$a")
    else
      [ "$a" = "" ] && { AUDIT "REJECT: empty argument"; exit 1; }
      prog="$a"
    fi
  else
    ARGS+=("$a")
  fi
done
[ -n "$prog" ] || { AUDIT "REJECT: no program in argv"; exit 1; }

# --- validate env assignments (allowlist) -------------------------------------
keylist=""
for a in "${ASGS[@]}"; do
  k="${a%%=*}"
  case "$k" in
    USER|LOCALE_ARCHIVE|PATH|NIX_PATH|HOME|TMPDIR) : ;;
    *) AUDIT "REJECT: disallowed env key '$k'"; exit 1 ;;
  esac
  keylist="${keylist}${k},"
done
AUDIT "env keys (${#ASGS[@]}): ${keylist%?}"

# --- validate program -----------------------------------------------------------
case "$prog" in
  /nix/store/*/bin/switch-to-configuration) : ;;
  *) AUDIT "REJECT: program '$prog' not allowed"; exit 1 ;;
esac

# The program store path must be a `nixos-system-<this host>` derivation, so
# only THIS host's own system can ever be activated here. `nix derivation
# show <output path>` answers {"derivations":{"<drv-basename>.drv":{...}}} —
# take that key and re-assemble the full drv store path.
drvkey="$("$NIX" derivation show "$prog" 2>/dev/null | "$JQ" -r '(.derivations | keys | .[0]) // empty' 2>/dev/null || true)"
drv="/nix/store/${drvkey}"
case "$drv" in
  /nix/store/*-nixos-system-"$HOST"-*) AUDIT "drv ok: $drv" ;;
  *) AUDIT "REJECT: '$prog' is not a nixos-system-$HOST derivation (drv='$drv')"; exit 1 ;;
esac

# --- validate subcommand ----------------------------------------------------------
sub="${ARGS[0]:-}"
case "$sub" in
  test|switch|dry-activate|activate|rollback) AUDIT "subcommand: $sub" ;;
  *) AUDIT "REJECT: subcommand '$sub' not allowed"; exit 1 ;;
esac

# --- elevate (re-exec self via sudo) or run as root --------------------------------
# `sudo -n` never prompts: the NOPASSWD rule (nixos/modules/default/
# nh-admin-gate.nix) covers exactly this store path and nothing else.
# $0 is the store path nh invoked us with; the re-executed copy re-runs this
# whole script as root and hits the env-exec below.
if [ "$(id -u)" -ne 0 ]; then
  AUDIT "re-exec via sudo (euid=$(id -u))"
  exec "$SUDO" -n "$0" env "$@"
fi

# --- run as root: exec the validated command exactly ------------------------------
exec "$ENV" ${ASGS[@]+"${ASGS[@]}"} "$prog" ${ARGS[@]+"${ARGS[@]}"}
