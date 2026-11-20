{ buildGoModule, lib }:

buildGoModule {
  pname = "llama-idle-proxy";
  version = "0.1.0";
  src = ../../static/llama-idle-proxy;

  # stdlib-only (no vendor dir, no go.sum)
  vendorHash = null;

  meta = {
    description = "Reverse proxy for llama-server: starts the backend on first request and stops it when idle, so GPU VRAM is only occupied while the model is in use";
    homepage = "https://github.com/anderer/flake";
    license = lib.licenses.asl20;
    mainProgram = "llama-idle-proxy";
  };
}
