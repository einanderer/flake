{
  lib,
  stdenv,
  python314Packages,
}:
let
  mcpPkg = python314Packages.mcp;
in
stdenv.mkDerivation {
  pname = "self-admin-mcp";
  version = "0.1.0";

  src = ../../static/self-admin-mcp;

  # `mcpPkg`'s `bin/.mcp-wrapped` is the python bootstrap whose `shebang +
  # coding + addsitedir` lines the wrapper below mirrors, so the generated
  # wrapper is a valid python shebang script that finds every mcp+dep
  # site-packages without a venv (same pattern as the old whisper-mcp rule).
  buildInputs = [ mcpPkg ];

  installPhase = ''
        set -e

        # --- copy python source -----------------------------------------------
        mkdir -p $out/lib/python/self-admin-mcp
        cp $src/src/main.py $out/lib/python/self-admin-mcp/main.py

        # --- assemble the python `bin/self-admin-mcp` wrapper -----------------
        #  1) shebang + coding marker from mcp's bootstrap (the real python)
        #  2) the addsitedir(...) line (adds every mcp + dep site-packages)
        #  3) our entry point — `import main; main.main()`
        mkdir -p $out/bin
        {
          sed -n '1,2p' ${mcpPkg}/bin/.mcp-wrapped
          grep 'addsitedir' ${mcpPkg}/bin/.mcp-wrapped
          cat <<PYEOF
    import os, sys
    sys.path.insert(0, "$out/lib/python/self-admin-mcp")
    import main
    main.main()
    PYEOF
        } > $out/bin/self-admin-mcp
        chmod +x $out/bin/self-admin-mcp
  '';

  meta = with lib; {
    description = "MCP stdio server for self-administering the local NixOS flake via nh";
    license = licenses.mit;
    mainProgram = "self-admin-mcp";
  };
}
