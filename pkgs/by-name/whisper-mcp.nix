{
  stdenv,
  python314Packages,
  whisper-cpp,
}:
let
  mcpPkg = python314Packages.mcp;
in
stdenv.mkDerivation {
  name = "whisper-mcp";
  version = "0.1.0";

  src = ../../static/whisper-mcp;

  # mcpPkg — its `bin/.mcp-wrapped` is a python bootstrap.  The whisper-mcp
  # wrapper mirrors its `shebang + coding marker + addsitedir` lines so the
  # generated wrapper is a valid python shebang script that finds both
  # mcp's site-packages AND our own `lib/python/whisper-mcp`.
  buildInputs = [ mcpPkg ];

  # `installPhase` — the `buildInputs`-linked `mcpPkg` exposes `bin/.mcp-wrapped`
  # (the python bootstrap that the wrapper mirrors).  The `installPhase` is
  # Nix-interpolated with `${mcpPkg}` (let-bound in outer `let`) so the
  # Nix value of `mcpPkg` substitutes at Nix time.
  #
  # For `whisper-cpp`: we copy `bin/` wholesale so `whisper-cli` sits on
  # $out/bin (PATH-reachable from the MCP wrapper + its `subprocess.run`).
  #
  # installPhase is a Nix string.  In a Nix string, `$name` (where `name`
  # is a Nix expression in scope) interpolates at Nix time to the string.
  # `$out` is a Nix value let-bound in stdenv's internal finalAttrs.
  # `$src` is let-bound in finalAttrs (the source path).
  # `${whisper-cpp}/bin` Nix-interpolates `whisper-cpp` (let-bound in outer
  # `let`) to its store path (e.g., /nix/store/iv084z-whisper-cpp-1.9.2).
  # `${mcpPkg}/bin/.mcp-wrapped` Nix-interpolates the mcp package path.
  installPhase = ''
     set -e

     # --- copy python source -----------------------------------------------
     mkdir -p $out/lib/python/whisper-mcp
     cp $src/src/main.py $out/lib/python/whisper-mcp/main.py

     # --- expose whisper-cpp `bin/whisper-cli` inside $out/bin/ ----------
     #  The MCP wrapper resolves `whisper-cli` by PATH (`shutil.which`),
     #  so `whisper-cli` must be reachable from the wrapper's $out/bin.
     #  Just copy the file (keeps exec bit, preserves RUNPATH baked at
     #  the dep's build time).
     mkdir -p $out/bin
     cp -a ${whisper-cpp}/bin/whisper-cli $out/bin/

     # --- assemble the python `bin/whisper-mcp` wrapper -----------------
     #  1) shebang + coding marker from mcp's bootstrap (the real python)
     #  2) the addsitedir(...) line (adds every mcp + dep site-packages)
     #  3) our entry point — `import main; main.main()`
     {
       sed -n '1,2p' ${mcpPkg}/bin/.mcp-wrapped
       grep 'addsitedir' ${mcpPkg}/bin/.mcp-wrapped
       cat <<PYEOF
    import os, sys
    sys.path.insert(0, "$out/lib/python/whisper-mcp")
    import main
    main.main()
    PYEOF
     } > $out/bin/whisper-mcp
     chmod +x $out/bin/whisper-mcp
  '';
}
