{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "hello-world-nix";
  version = "0.1.0";

  src = lib.mkDerivation {
    name = "src";
    buildPhase = ''
      mkdir -p $out
      echo 'echo "Hello from Nix-Dev-Assistant!"' > $out/hello
      chmod +x $out/hello
    '';
  };

  installPhase = ''
    mkdir -p $out/bin
    cp $src/hello $out/bin/hello
  '';

  meta = {
    description = "Ein einfaches Testpaket zur Validierung des nix-dev-assistant Skills.";
  };
}
