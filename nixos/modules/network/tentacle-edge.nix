{
  config,
  lib,
  ...
}:
let
  cfg = config.anderer.network.tentacleEdge;
in
{
  options.anderer.network.tentacleEdge = {
    enable = lib.mkEnableOption "tentacle WAN (ens3), forwarding, and nftables edge policy";

    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "ens3";
      description = "Public uplink interface (Hetzner).";
    };

    vpnInterface = lib.mkOption {
      type = lib.types.str;
      default = "ttvpn";
      description = "WireGuard hub interface for NAT and forwarding.";
    };

    ipv6Address = lib.mkOption {
      type = lib.types.str;
      default = "2a01:4f8:c2c:6a6f::1/64";
      description = "Static Hetzner /64 address on WAN.";
    };

    ipv6Gateway = lib.mkOption {
      type = lib.types.str;
      default = "fe80::1";
      description = "Default IPv6 gateway on WAN.";
    };

    allowedTcpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        22
        80
        443
      ];
      description = ''
        TCP ports on the WAN interface allowed to reach this host.
        Includes 22 for SSH (replaces services.openssh.openFirewall while the
        NixOS firewall is disabled here).
      '';
    };

    allowedUdpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        53
        52342
        4445
      ];
      description = "UDP ports allowed on the WAN interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Port 22 was previously opened via openFirewall + networking.firewall.
    services.openssh.openFirewall = lib.mkForce false;

    networking = {
      useDHCP = false;
      firewall.enable = false;
      nat.enable = false;
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    systemd.network.networks."50-${cfg.wanInterface}" = {
      matchConfig.Name = cfg.wanInterface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      addresses = [
        { Address = cfg.ipv6Address; }
      ];
      routes = [
        {
          Destination = "::/0";
          Gateway = cfg.ipv6Gateway;
        }
      ];
    };

    networking.nftables.enable = true;
    networking.nftables.tables."tentacle-edge" = {
      family = "inet";
      content = ''
        define WAN = ${cfg.wanInterface}
        define VPN = ${cfg.vpnInterface}
        define VPN_NET4 = 10.111.101.0/24
        define HOME_NET4 = 10.0.0.0/24

        chain input {
          type filter hook input priority filter; policy drop;

          iif "lo" accept comment "localhost"
          ct state established,related accept comment "established"

          ip protocol icmp accept comment "ICMPv4"
          ip6 nexthdr icmpv6 accept comment "ICMPv6"

          iifname $WAN tcp dport { ${lib.concatStringsSep ", " (map toString cfg.allowedTcpPorts)} } accept comment "WAN TCP (SSH, nginx, …)"
          iifname $WAN udp dport { ${lib.concatStringsSep ", " (map toString cfg.allowedUdpPorts)} } accept comment "WAN UDP (DNS, WireGuard, …)"

          iifname $VPN accept comment "alles auf ttvpn (SSH, Grafana intern, …)"
        }

        chain forward {
          type filter hook forward priority filter; policy drop;

          ct state established,related accept comment "established forward"

          iifname $VPN oifname $WAN accept comment "VPN → Internet"
          iifname $WAN oifname $VPN ct state established,related accept comment "Internet → VPN"

          iifname $VPN oifname $VPN accept comment "VPN peer ↔ peer"

          iifname $VPN ip saddr $HOME_NET4 accept comment "Heimnetz → VPN"
          iifname $VPN ip daddr $HOME_NET4 accept comment "VPN → Heimnetz"

          iifname $WAN oifname $VPN drop comment "kein WAN → VPN ohne WG"
        }

        chain output {
          type filter hook output priority filter; policy accept;
        }
      '';
    };

    networking.nftables.tables."tentacle-nat4" = {
      family = "ip";
      content = ''
        define WAN = ${cfg.wanInterface}
        define VPN_NET4 = 10.111.101.0/24

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          ip saddr $VPN_NET4 oifname $WAN masquerade comment "VPN-v4 → Internet"
        }
      '';
    };

    networking.nftables.tables."tentacle-nat6" = {
      family = "ip6";
      content = ''
        define WAN = ${cfg.wanInterface}
        define VPN_ULA6 = fd72:db04:ef1a:e953::/64

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          ip6 saddr $VPN_ULA6 oifname $WAN masquerade comment "VPN-ULA → Hetzner-v6"
        }
      '';
    };
  };
}
