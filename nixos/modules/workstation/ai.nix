{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
  aiPackages = [
    pkgs.pi-coding-agent
  ];
in
{
  config = mkIf cfg.enable {
    # llama.cpp server (llama-server) replaces ollama (2026-11-18): same workload
    # (Qwen3.8-27B-UD-IQ2_S + MTP draft), flags ported 1:1 from the old ollama
    # config. Models live under the service's StateDirectory /var/lib/llama-cpp.
    services.llama-cpp = {
      enable = cfg.ai;
      package = pkgs.llama-cpp-rocm;
      settings = {
        host = "127.0.0.1";
        port = 8080;
        model = "/var/lib/llama-cpp/models/Qwen3.8-27B-UD-IQ2_S.gguf";
        spec-draft-model = "/var/lib/llama-cpp/models/mtp-Qwen3.8-27B-Q4_0.gguf";
        spec-type = "draft-mtp";
        spec-draft-n-max = 4;
        # ported from OLLAMA_CONTEXT_LENGTH / OLLAMA_KV_CACHE_TYPE / OLLAMA_FLASH_ATTENTION
        ctx-size = 98304;
        cache-type-k = "q4_0";
        cache-type-v = "q4_0";
        flash-attn = "on";
        # Ollama defaults ported 1:1
        batch-size = 512;
        ubatch-size = 512;
        context-shift = true;
        keep = 4;
        no-webui = true;
        # stable API name: clients keep requesting "qwen3.8-27b-ud-iq2s-mtp"
        alias = "qwen3.8-27b-ud-iq2s-mtp";
      };
    };
    environment.systemPackages = aiPackages ++ cfg.aiPackages;
  };
}
