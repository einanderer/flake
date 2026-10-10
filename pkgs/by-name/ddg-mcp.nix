{
  lib,
  stdenv,
  python314Packages,
}:
stdenv.mkDerivation {
  name = "ddg-mcp";
  version = "0.1.0";
  src = ../../static/ddg-mcp;
  buildInputs = [
    python314Packages.python
    python314Packages.mcp
  ];
  installPhase = ''
    mkdir -p $out/lib/python/ddg-mcp
    cp -r $src/src/*.py $out/lib/python/ddg-mcp/
    mkdir -p $out/bin
    cat > $out/bin/ddg-mcp <<EOF
#!/usr/bin/env bash
exec "${python314Packages.python}/bin/python3" "$out/lib/python/ddg-mcp/main.py" "$@"
EOF
    chmod +x $out/bin/ddg-mcp
  '';
}
