{
  packages,
  config,
  lib,
  ...
}:
{
  options.andher.security.nhAdminGate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow the user to run the `nh-admin-gate` without a password
        (sudoers rule, stable sw path
        /run/current-system/sw/bin/nh-admin-gate). The gate is the
        OS-level layer of the MCP self-admin security model: only that
        exact path is reachable via sudo, and it audits + re-validates
        every argv it executes (see
        pkgs/by-name/nh-admin-gate.nix and docs/mcp-self-admin.md).
      '';
    };
  };

  config = lib.mkIf (config.andher.security.nhAdminGate.enable) {
    # The gate must be a systemClosure member so the stable
    # /run/current-system/sw/bin/nh-admin-gate path survives both boots and
    # nix-collect-gc-candidates — a volatile store path would leave the
    # passwordless self-admin route broken after GC.
    environment.systemPackages = [ packages.nh-admin-gate ];
    security.sudo-rs.extraRules = [
      {
        users = [ "anderer" ];
        groups = [ ];
        host = "ALL";
        commands = [
          {
            command = "/run/current-system/sw/bin/nh-admin-gate";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
