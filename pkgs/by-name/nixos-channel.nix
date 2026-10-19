{
  writers,
  curl,
  jq,
  coreutils,
  ...
}:
writers.writeBashBin "nixos-channel" ''
  set -u

  CHANNEL="''${NIXOS_CHANNEL:-nixos-unstable-small}"
  API="https://prometheus.nixos.org/api/v1/query"
  CURL=${curl}/bin/curl
  JQ=${jq}/bin/jq
  now="$(${coreutils}/bin/date +%s)"
  Q_REV="channel_revision%7Bchannel%3D%22''${CHANNEL}%22%7D"
  Q_UPD="channel_update_time%7Bchannel%3D%22''${CHANNEL}%22%7D"
  Q_FAIL="hydra_job_failed%7Bchannel%3D%22''${CHANNEL}%22%7D"

  get() {
    { "$CURL" -fsS --max-time 15 "''${API}?query=$1" 2>/dev/null || true; } | "$JQ" -r "try $2 // \"null\"" 2>/dev/null
  }

  rev="$(get "$Q_REV" '.data.result[0].metric.revision')"
  label="$(get "$Q_REV" '.data.result[0].metric.status')"
  upd="$(get "$Q_UPD" '.data.result[0].value[1]')"
  fail="$(get "$Q_FAIL" '.data.result[0].value[1]')"

  # nixos-version: <maj>.<minor>.<nixpkgs-short-sha>-<flake-repo-sha>
  myrev=""
  if [ -r /run/current-system/nixos-version ]; then
    IFS='.' read -r _ _ myrev < /run/current-system/nixos-version
    myrev="''${myrev%%-*}"
  fi

  mybuild=""
  link="$(${coreutils}/bin/readlink -f /run/current-system 2>/dev/null || true)"
  if [ -n "$link" ] && [ -r "$link.narinfo" ]; then
    while IFS= read -r line; do
      case "$line" in
        'Timestamp:'*) mybuild="''${line#Timestamp: }";;
      esac
    done < "$link.narinfo"
  fi

  age() {
    a=$(( now - $1 ))
    [ "$a" -lt 0 ] && a=0
    printf '%dd %dh %dm' $(( a / 86400 )) $(( (a % 86400) / 3600 )) $(( (a % 3600) / 60 ))
  }

  if [ -z "$rev" ] || [ "$rev" = "null" ]; then
    printf '?\nNixOS %s: no channel data (API unreachable or channel unknown)\noffline\n' "$CHANNEL"
    exit 0
  fi

  short7="''${rev:0:7}"
  short12="''${rev:0:12}"
  tt="NixOS $CHANNEL ($label)"
  [ -n "$mybuild" ] && tt="$tt<br/>System: built $(age "$mybuild") ago"
  [ -n "$upd" ] && [ "$upd" != "null" ] && tt="$tt<br/>Channel updated $(age "$upd") ago"

  if [ "$fail" = "1" ]; then
    class="fail"; icon="✗"
    tt="$tt<br/>Hydra build for this channel is failing"
  elif [ -n "$myrev" ]; then
    if [ "$short7" = "$myrev" ]; then
      class="ok"; icon="✓"
      tt="$tt<br/>Your system is up to date ($short7)"
    else
      class="update"; icon="↑"
      tt="$tt<br/>Update available: $short12 (system has $myrev)"
    fi
  else
    class="update"; icon="↑"
    tt="$tt<br/>Update available: $short12 (system revision unknown)"
  fi

  printf '%s\n%s\n%s\n' "$icon" "$tt" "$class"
''
