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
#   <NH>/bin/nh    (content-addressed nh store path) — exactly
#         `__privileged <JSON op>` with <JSON op> =
#         {"log_level":...,"op":{"<op>":{...}}}, <op> in
#         {NixosActivate, NixosRollback}. The JSON names the system
#         derivation / profiles to activate; validated per op below.
#   <SYSTEM>/bin/switch-to-configuration   (sub: test|switch|dry-activate|activate|rollback|boot)
#   nix    (bare; resolved to /bin/nix via $NIX)   — exactly `build --no-link --profile <path> <drv-output>`, <path>=/nix/var/nix/profiles/system, <drv-output> is the nixos-system drv built for this host (driven by `nix derivation show`).
#   ln     (bare; resolved to $LN, coreutils) — exactly `-sfn <src> /nix/var/nix/profiles/system`, <src> must match /nix/var/nix/profiles/system-*.
#
# Every accepted form re-verifies its target with `nix derivation show`:
# only a `nixos-system-<this host>` derivation can ever be activated here, so
# neither a model-/MCP-crafted argv nor a foreign system derivation can
# escalate. The gate audits + validates, then re-executes itself via
# `sudo -n` (a single NOPASSWD sudoers rule for exactly this store path is the
# only privilege it ever receives) and, as root, execs the command exactly.
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
# Accept exactly: <SYSTEM>/bin/switch-to-configuration, bare `nix`, bare
# `ln`, or the content-addressed nh store path itself
# (<NH>/bin/nh __privileged <JSON op>, the current elevation contract).
# All forms end in a `nix derivation show` re-verification against
# `nixos-system-<this host>` (see below / in-branch).
drvskip=0
case "$prog" in
  /nix/store/*/bin/switch-to-configuration) : ;;
  nix) prog="$NIX" ;;
  ln)  prog="$LN" ;;
  /nix/store/*/bin/nh)
    # New nh elevation contract (nh >= 4.5.0): nh re-invokes ITS OWN store
    # path with `__privileged <JSON op>`. Validate the op JSON field by
    # field; the op is the only description of what gets activated.
    [ "${#ARGS[@]}" -eq 2 ] || { AUDIT "REJECT: nh argv arity ${#ARGS[@]} != 2"; exit 1; }
    [ "${ARGS[0]}" = "__privileged" ] || { AUDIT "REJECT: nh argv[0] '${ARGS[0]}' != '__privileged'"; exit 1; }
    opjson="${ARGS[1]}"
    jget() { printf '%s' "$opjson" | "$JQ" -r "$1" 2>/dev/null || true; }
    opname=$(jget '(.op | keys | .[0]) // empty')
    case "$opname" in
      NixosActivate)
        [ "$(jget '.op.NixosActivate.action // empty')" = "Switch" ] || { AUDIT "REJECT: NixosActivate action != 'Switch'"; exit 1; }
        [ "$(jget '.op.NixosActivate.install_bootloader')" = "false" ] || { AUDIT "REJECT: install_bootloader must be false"; exit 1; }
        [ "$(jget '.op.NixosActivate.continue_on_activation_failure')" = "false" ] || { AUDIT "REJECT: continue_on_activation_failure must be false"; exit 1; }
        [ "$(jget '.op.NixosActivate.nix_args | length // 0')" -eq 0 ] || { AUDIT "REJECT: NixosActivate nix_args must be empty"; exit 1; }
        system=$(jget '.op.NixosActivate.system // empty')
        s2c=$(jget '.op.NixosActivate.switch_to_configuration // empty')
        [ -n "$system" ] && [ -n "$s2c" ] || { AUDIT "REJECT: NixosActivate missing system/switch_to_configuration"; exit 1; }
        [ "$s2c" = "$system/bin/switch-to-configuration" ] || { AUDIT "REJECT: s2c '${s2c}' != '<system>/bin/switch-to-configuration'"; exit 1; }
        drvkey=$("$NIX" derivation show "$system" 2>/dev/null | "$JQ" -r '(.derivations | keys | .[0]) // empty' 2>/dev/null || true)
        drv="/nix/store/${drvkey}"
        case "$drv" in
          /nix/store/*-nixos-system-"$HOST"-*) AUDIT "drv ok: $drv" ;;
          *) AUDIT "REJECT: '$system' is not a nixos-system-$HOST derivation (drv='$drv')"; exit 1 ;;
        esac
        AUDIT "nh NixosActivate ok: action=Switch systemd_run=$(jget '.op.NixosActivate.systemd_run // empty')"
        ;;
      NixosRollback)
        tp=$(jget '.op.NixosRollback.target_profile // empty')
        s2c=$(jget '.op.NixosRollback.switch_to_configuration // empty')
        case "$tp" in
          /nix/var/nix/profiles/system-[0-9]*-link) : ;;
          *) AUDIT "REJECT: target_profile '$tp' is not a system-<gen>-link profile"; exit 1 ;;
        esac
        [ -L "$tp" ] || { AUDIT "REJECT: target_profile '$tp' does not exist"; exit 1; }
        tpr=$(readlink "$tp")
        [ -n "$tpr" ] || { AUDIT "REJECT: target_profile '$tp' does not resolve"; exit 1; }
        [ "$s2c" = "$tp/bin/switch-to-configuration" ] || { AUDIT "REJECT: s2c '${s2c}' != '<target_profile>/bin/switch-to-configuration'"; exit 1; }
        drvkey=$("$NIX" derivation show "$tpr" 2>/dev/null | "$JQ" -r '(.derivations | keys | .[0]) // empty' 2>/dev/null || true)
        drv="/nix/store/${drvkey}"
        case "$drv" in
          /nix/store/*-nixos-system-"$HOST"-*) AUDIT "rollback drv ok: $drv" ;;
          *) AUDIT "REJECT: rollback target '$tpr' is not a nixos-system-$HOST derivation (drv='$drv')"; exit 1 ;;
        esac
        AUDIT "nh NixosRollback ok: target=$tp"
        ;;
      *) AUDIT "REJECT: unknown nh op '${opname}'"; exit 1 ;;
    esac
    drvskip=1
    ;;
  *) AUDIT "REJECT: program '$prog' not allowed"; exit 1 ;;
esac

# --- validate program-specific argv -----------------------------------------------
# s2c : <SYSTEM>/bin/switch-to-configuration <sub>   (sub checked below)
# nix : build --no-link --profile /nix/var/nix/profiles/system <drv-output>
# ln  : -sfn <src> /nix/var/nix/profiles/system
# (nh __privileged: argv already validated in the program case above.)
if [ "$drvskip" -eq 0 ]; then
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
  # only THIS host's own system can ever be activated here. `nix derivation
  # show <path>` answers {"derivations":{"<drv-basename>.drv":{...}}} — take
  # that key and re-assemble the full drv store path. (ln is excluded: it
  # only touches the profile symlinks, whose argv is pinned by string
  # pattern above.)
  if [ "$prog" != "$LN" ]; then
    drvkey=$("$NIX" derivation show "$drvtarget" 2>/dev/null | "$JQ" -r '(.derivations | keys | .[0]) // empty' 2>/dev/null || true)
    drv="/nix/store/${drvkey}"
    case "$drv" in
      /nix/store/*-nixos-system-"$HOST"-*) AUDIT "drv ok: $drv" ;;
      *) AUDIT "REJECT: '$drvtarget' is not a nixos-system-$HOST derivation (drv='$drv')"; exit 1 ;;
    esac
  fi
fi

# --- validate subcommand ----------------------------------------------------------
# (nh __privileged: the op was validated in the program case; its subcommand
# is not free text.)
if [ "$drvskip" -eq 0 ]; then
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
fi

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
