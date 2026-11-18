{
  packages,
  config,
  lib,
  ...
}:
{
  options.andher.mcp.selfAdminMcp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install the self-admin-mcp binary to the stable system path
      /run/current-system/sw/bin/self-admin-mcp (systemClosure member,
      GC-proof). Harness configs (~/.pi/agent/mcp.json) reference that
      stable path
      instead of a volatile /nix/store path, so flake rebuilds can
      never leave the MCP server pointing at a GC'd derivation.
      (Companion to andher.security.nhAdminGate: that one pins the
      gate, this one pins the MCP server itself.)
    '';
  };

  config = lib.mkIf (config.andher.mcp.selfAdminMcp.enable) {
    environment.systemPackages = [ packages.self-admin-mcp ];
  };
}
