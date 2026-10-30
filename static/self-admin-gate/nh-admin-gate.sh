#!@BASH@/bin/bash
# nh-admin-gate — OS-level gate for `nh` self-admin mutations (layer 3 of the
# MCP self-admin security; see docs/mcp-self-admin.md).
#
# The MCP server drives nh as:
#     nh os switch .#<host> --elevation-strategy <this binary's store path>
# nh then invokes THIS script (as the unprivileged user) as
#     nh-admin-gate env USER=... LOCALE_ARCHIVE=... PATH=... NIX_PATH=...
#         <PROGRAM> <args...>
# where <PROGRAM> is one of:
#   <SYSTEM>/bin/switch-to-configuration   (sub: test|switch|dry-activate|activate|rollback|boot)
#   nix    (bare; resolved to /bin/nix via $NIX)   — exactly `build --no-link --profile <path> <drv-output>`, <path>=/nix/var/nix/profiles/system, <drv-output> is the nixos-system drv built for this host (driven by `nix derivation show`).
#   ln     (bare; resolved to $LN, coreutils) — exactly `-sfn <src> /nix/var/nix/profiles/system`, <src> must match /nix/var/nix/profiles/system-*.
# where <SYSTEM> is the built nixos-system-<host>-... store path.
#
# The gate audits + validates every part of that argv, re-executes itself via
# `sudo -n` (a single NOPASSWD sudoers rule for exactly this store path is the
# only privilege it ever receives), and as root execs the activation command
# exactly — so neither a model- or MCP-crafted argv nor an out-of-allowlist
# system derivation can ever be activated on this host.
set -euo pipefail

NIX=@NIX@/bin/nix
LN=@LN@/bin/ln
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
# Accept exactly: <SYSTEM>/bin/switch-to-configuration, or bare `nix`, or bare
# `ln`. nh resolves bare `nix`/`ln` via PATH (observed in the nh 4.4.2 os
# switch/rollback elevation set), so pin them to the absolute store paths
# $NIX/$LN and validate their argv below.
case "$prog" in
  /nix/store/*/bin/switch-to-configuration) : ;;
  nix) prog="$NIX" ;;
  ln)  prog="$LN" ;;
  *) AUDIT "REJECT: program '$prog' not allowed"; exit 1 ;;
esac

# --- validate program-specific argv -----------------------------------------------
# s2c : <SYSTEM>/bin/switch-to-configuration <sub>   (sub checked below)
# nix : build --no-link --profile /nix/var/nix/profiles/system <drv-output>
# ln  : -sfn <src> /nix/var/nix/profiles/system
drvtarget="$prog"   # s2c default: the s2c store path itself
case "$prog" in
  "$NIX")
    [ "${#ARGS[@]}" -eq 5 ] || { AUDIT "REJECT: nix argv arity ${#ARGS[@]} != 5"; exit 1; }
    [ "${ARGS[0]}" = "build" ] || { AUDIT "REJECT: nix: '${ARGS[0]}' != 'build'"; exit 1; }
    [ "${ARGS[1]}" = "--no-link" ] || { AUDIT "REJECT: nix: argv[1] != '--no-link'"; exit 1; }
    [ "${ARGS[2]}" = "--profile" ] || { AUDIT "REJECT: nix: argv[2] != '--profile'"; exit 1; }
    [ "${ARGS[3]}" = "/nix/var/nix/profiles/system" ] || { AUDIT "REJECT: nix: profile '${ARGS[3]}' != /nix/var/nix/profiles/system"; exit 1; }
    drvtarget="${ARGS[4]}"
    AUDIT "nix build ok: profile=/nix/var/nix/profiles/system target=${ARGS[4]}"
    ;;
  "$LN")
    [ "${#ARGS[@]}" -eq 3 ] || { AUDIT "REJECT: ln argv arity ${#ARGS[@]} != 3"; exit 1; }
    [ "${ARGS[0]}" = "-sfn" ] || { AUDIT "REJECT: ln: flag '${ARGS[0]}' != '-sfn'"; exit 1; }
    [ "${ARGS[2]}" = "/nix/var/nix/profiles/system" ] || { AUDIT "REJECT: ln: target '${ARGS[2]}' != /nix/var/nix/profiles/system"; exit 1; }
    case "${ARGS[1]}" in
      /nix/var/nix/profiles/system-*) AUDIT "ln src ok: ${ARGS[1]}" ;;
      *) AUDIT "REJECT: ln: src '${ARGS[1]}' is not a /nix/var/nix/profiles/system-<gen> profile"; exit 1 ;;
    esac
    ;;
  *) : ;;   # s2c — argv pinned in the subcommand check below
esac

# The target store path must be a `nixos-system-<this host>` derivation, so
# only THIS host's own system can ever be activated here. `nix derivation show
# <path>` answers {"derivations":{"<drv-basename>.drv":{...}}} — take that key
# and re-assemble the full drv store path. (ln is excluded: it only touches
# the profile symlinks, whose argv is pinned by string pattern above.)
if [ "$prog" != "$LN" ]; then
  drvkey="$("$NIX" derivation show "$drvtarget" 2>/dev/null | "$JQ" -r '(.derivations | keys | .[0]) // empty' 2>/dev/null || true)"
  drv="/nix/store/${drvkey}"
  case "$drv" in
    /nix/store/*-nixos-system-"$HOST"-*) AUDIT "drv ok: $drv" ;;
    *) AUDIT "REJECT: '$drvtarget' is not a nixos-system-$HOST derivation (drv='$drv')"; exit 1 ;;
  esac
fi

# --- validate subcommand ----------------------------------------------------------
case "$prog" in
  "$NIX" | "$LN") : ;;   # argv already pinned above
  *)
    sub="${ARGS[0]:-}"
    case "$sub" in
      test|switch|dry-activate|activate|rollback|boot) AUDIT "subcommand: $sub" ;;
      *) AUDIT "REJECT: subcommand '$sub' not allowed"; exit 1 ;;
    esac
  ;;
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
