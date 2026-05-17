{
  config,
  lib,
  ...
}:
let
  cfg = config.anderer.network.ttvpn;
  iface = cfg.interfaceName;
in
{
  options.anderer.network.ttvpn = {
    enable = lib.mkEnableOption "ttvpn WireGuard mesh";

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "ttvpn";
      description = "WireGuard interface name.";
    };

    mtu = lib.mkOption {
      type = lib.types.int;
      default = 1300;
      description = "WireGuard interface MTU.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "WireGuard private key (SOPS path).";
    };

    hub = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            listenPort = lib.mkOption {
              type = lib.types.port;
              description = "UDP listen port on the VPN hub.";
            };
            addresses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Interface addresses, e.g. 10.111.101.1/24.";
            };
            peers = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      description = "Peer label (documentation only).";
                    };
                    publicKey = lib.mkOption {
                      type = lib.types.str;
                      description = "WireGuard public key of the peer.";
                    };
                    allowedIPs = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      description = "Allowed IPs for this peer.";
                    };
                    presharedKeyFile = lib.mkOption {
                      type = lib.types.nullOr lib.types.path;
                      default = null;
                      description = "Optional preshared key file path.";
                    };
                  };
                }
              );
              description = "WireGuard peers on the hub.";
            };
          };
        }
      );
      default = null;
      description = "Hub configuration (tentacle). Mutually exclusive with client.";
    };

    client = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            addresses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Addresses on the local WireGuard interface.";
            };
            endpoint = lib.mkOption {
              type = lib.types.str;
              description = "Hub endpoint host:port.";
            };
            peerPublicKey = lib.mkOption {
              type = lib.types.str;
              description = "Hub public key.";
            };
            allowedIPs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Split-tunnel prefixes routed via the VPN.";
            };
            presharedKeyFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Optional preshared key file path.";
            };
            persistentKeepalive = lib.mkOption {
              type = lib.types.int;
              default = 25;
              description = "NAT traversal keepalive interval in seconds.";
            };
          };
        }
      );
      default = null;
      description = "Client configuration (laptops). Mutually exclusive with hub.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.hub != null) != (cfg.client != null);
        message = "anderer.network.ttvpn: set exactly one of hub or client.";
      }
      {
        assertion = cfg.privateKeyFile != null;
        message = "anderer.network.ttvpn.privateKeyFile must be set.";
      }
    ];

    systemd.network = {
      netdevs."40-${iface}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = iface;
          MTUBytes = cfg.mtu;
        };
        wireguardConfig = lib.mkMerge [
          {
            PrivateKeyFile = cfg.privateKeyFile;
          }
          (lib.mkIf (cfg.hub != null) {
            ListenPort = cfg.hub.listenPort;
          })
          (lib.mkIf (cfg.client != null) {
            RouteTable = "main";
          })
        ];
        wireguardPeers =
          if cfg.hub != null then
            map (
              peer:
              lib.filterAttrs (_: v: v != null) {
                PublicKey = peer.publicKey;
                AllowedIPs = peer.allowedIPs;
                PresharedKeyFile = peer.presharedKeyFile;
              }
            ) cfg.hub.peers
          else
            [
              (lib.filterAttrs (_: v: v != null) {
                PublicKey = cfg.client.peerPublicKey;
                Endpoint = cfg.client.endpoint;
                AllowedIPs = cfg.client.allowedIPs;
                PersistentKeepalive = cfg.client.persistentKeepalive;
                PresharedKeyFile = cfg.client.presharedKeyFile;
              })
            ];
      };

      networks."40-${iface}" = {
        matchConfig.Name = iface;
        address = if cfg.hub != null then cfg.hub.addresses else cfg.client.addresses;
        networkConfig = lib.mkIf (cfg.hub != null) {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
      };
    };
  };
}
