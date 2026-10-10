{
  stdenv,
  python314Packages,
}:
let
  mcpPkg = python314Packages.mcp;
in
stdenv.mkDerivation {
  name = "ddg-mcp";
  version = "0.1.0";

  src = ../../static/ddg-mcp;

  # mcpPkg — its `bin/.mcp-wrapped` is a python bootstrap script:
  #   line 1 : shebang → the python3.14 interpreter
  #   line 3 : the single addsitedir(...) line that adds every mcp +
  #            transitive dep site-packages dir to sys.path.
  # We copy those two lines verbatim into the `ddg-mcp` python wrapper,
  # so `import mcp.server` (and every transitive dep) resolves.
  buildInputs = [ mcpPkg ];

  installPhase = ''
        set -e

        # --- copy python sources -------------------------------------------
        mkdir -p $out/lib/python/ddg-mcp
        cp -r $src/src/main.py $src/src/engines.py $src/src/botguard.py \
             $out/lib/python/ddg-mcp/

        # --- assemble the ddg-mcp python wrapper ---------------------------
        # 1) shebang + coding marker from mcp's bootstrap (the real python)
        # 2) the addsitedir line (adds all mcp + dep site-packages)
        # 3) our entry point ($out is expanded by bash, see unquoted PYEOF)
        mkdir -p $out/bin
        {
          sed -n '1,2p' ${mcpPkg}/bin/.mcp-wrapped
          grep 'addsitedir' ${mcpPkg}/bin/.mcp-wrapped
          cat <<PYEOF
    import os, sys
    sys.path.insert(0, "$out/lib/python/ddg-mcp")
    import main
    main.main()
    PYEOF
        } > $out/bin/ddg-mcp
        chmod +x $out/bin/ddg-mcp
  '';
}
