{
  bash,
  lib,
  nh,
  nix,
  jq,
  coreutils,
  stdenv,
}:
# OS-level gate for `nh` self-admin mutations (layer 3; see
# docs/mcp-self-admin.md). The bash script lives in
# static/self-admin-gate/nh-admin-gate.sh (plain shell, so no nix-string
# escaping games); this rule only injects the store paths for bash/nh/nix/
# jq/coreutils via the @TOKEN@ substitution and puts the script at bin/.
# The @NH@ pin (content-addressed nh store path) lets the gate recognize
# the current `nh __privileged <JSON op>` elevation contract without
# parsing a version number from the binary.
stdenv.mkDerivation {
  pname = "nh-admin-gate";
  version = "1";
  dontBuild = true;
  dontInstallCheck = true;

  src = ../../static/self-admin-gate;

  installPhase = ''
    set -e
    mkdir -p $out/bin
    sed -e "s|@BASH@|${bash}|" \
        -e "s|@NH@|${nh}|" \
        -e "s|@NIX@|${nix}|" \
        -e "s|@LN@|${coreutils}|" \
        -e "s|@JQ@|${jq}|" \
        -e "s|@ENV@|${coreutils}|" \
        "$src/nh-admin-gate.sh" > "$out/bin/nh-admin-gate"
    chmod +x "$out/bin/nh-admin-gate"
  '';

  meta = with lib; {
    description = "OS-level elevation gate for nh self-admin mutations (MCP)";
    license = licenses.unlicense;
    mainProgram = "nh-admin-gate";
  };
}
