{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.anderer.os.workstation;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    services.ollama = {
      enable = cfg.ai;
      package = pkgs.ollama-rocm;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = "2h";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_NUM_THREADS = "8";
        OLLAMA_CONTEXT_LENGTH = "65536";
      };
      host = "127.0.0.1";
      port = 11434;
    };
  };
}
