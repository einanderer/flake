{
  packages,
  config,
  lib,
  ...
}:
{
  options.andher.security.nhAdminGate = {
    enable = {
      default = true;
      description = ''
        Allow the user to run the content-addressed `nh-admin-gate` without a
        password (sudoers rule). The gate is the OS-level layer of the MCP
        self-admin security model: only its exact store path is reachable via
        sudo, and it audits + re-validates every argv it executes (see
        pkgs/by-name/nh-admin-gate.nix and docs/mcp-self-admin.md).
      '';
    };
  };

  config = lib.mkIf (config.andher.security.nhAdminGate.enable) {
    security.sudo.extraRules = [
      {
        users = [ "anderer" ];
        groups = [ ];
        hosts = [ "ALL" ];
        commands = [
          {
            command = "${packages.nh-admin-gate}/bin/nh-admin-gate";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
