{
  config,
  lib,
  pkgs,
  packages,
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
    # llama.cpp server (llama-server) replaces ollama (2026-11-18): flags ported
    # 1:1 from the old ollama config. Models live under the service's StateDirectory
    # /var/lib/llama-cpp.
    # 2026-11-21: IQ2_S -> IQ4_XS (quality) and back the same day: IQ4_XS
    # (14.3 GB) + MTP draft (1.3 GB) does not fit in the RX 6950 XT's 16 GB
    # VRAM, so the KV cache falls back to CPU RAM and decode collapses from
    # ~45 to ~8 tok/s (flash-attn + KV shifting auto-disable). IQ2_S (7.9 GB)
    # fits with room to spare; serve it until VRAM grows. The legacy iq4xs
    # alias is kept comma-separated so clients pinned to it keep resolving.
    # 2026-11-20: on-demand only — the idle reverse proxy (llama-idle-proxy on
    # 127.0.0.1:8080) starts this service on first request and stops it when
    # idle, so the model's ~9 GB VRAM is only occupied while actually in use.
    # Port moved 8080 -> 8081 (backend); the proxy owns the client-facing 8080.
    systemd.services.llama-cpp = mkIf cfg.ai {
      # Backend: unit is created (so the idle proxy can `systemctl start` it on
      # demand) but not wanted by any target, so it does not auto-start at boot
      # and VRAM is only occupied while a request is in flight.
      enable = true;
      wantedBy = [ ];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "llama-cpp";
        CacheDirectory = "llama-cpp";
        WorkingDirectory = "/var/lib/llama-cpp";
        Environment = [ "LLAMA_CACHE=/var/cache/llama-cpp" ];
        Restart = "on-failure";
        RestartSec = "300";
        # Same flags as the deployed server; port moved 8080 -> 8081 (proxy owns 8080).
        ExecStart =
          "${pkgs.llama-cpp-rocm}/bin/llama-server "
          + "--alias qwen3.8-27b-ud-iq2s-mtp,qwen3.8-27b-ud-iq4xs-mtp "
          + "--model /var/lib/llama-cpp/models/Qwen3.8-27B-UD-IQ2_S.gguf "
          + "--spec-draft-model /var/lib/llama-cpp/models/mtp-Qwen3.8-27B-Q4_0.gguf "
          + "--spec-type draft-mtp --spec-draft-n-max 4 "
          + "--ctx-size 98304 --cache-type-k q4_0 --cache-type-v q4_0 "
          + "--flash-attn on --batch-size 512 --ubatch-size 512 "
          + "--context-shift --keep 4 --no-webui "
          + "--host 127.0.0.1 --port 8081";
      };
    };

    # Client-facing reverse proxy (127.0.0.1:8080), transparent to existing clients
    # (they still hit :8080). Starts llama-cpp.service on first request (waits up to
    # 90s for the model load) and stops it after 300s idle, freeing GPU VRAM.
    # Returns 503 while the backend is down or loading.
    systemd.services.llama-idle-proxy = mkIf cfg.ai {
      description = "Idle reverse proxy for llama-cpp (starts/stops backend on demand)";
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.systemd ];
      serviceConfig = {
        ExecStart =
          "${packages.llama-idle-proxy}/bin/llama-idle-proxy "
          + "--listen 127.0.0.1:8080 --backend 127.0.0.1:8081 "
          + "--service llama-cpp.service --idle 300";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
    environment.systemPackages = aiPackages ++ cfg.aiPackages;
  };
}
