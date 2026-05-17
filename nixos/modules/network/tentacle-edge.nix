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
  };

  config = lib.mkIf cfg.enable {
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
    networking.nftables.ruleset = ''
      # tentacle edge — WAN ens3 + VPN ttvpn (ersetzt networking.nat/firewall)

      define WAN = ${cfg.wanInterface}
      define VPN = ${cfg.vpnInterface}
      define VPN_NET4 = 10.111.101.0/24
      define HOME_NET4 = 10.0.0.0/24
      define VPN_ULA6 = fd72:db04:ef1a:e953::/64

      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          iif "lo" accept comment "localhost"
          ct state established,related accept comment "established"

          ip protocol icmp accept comment "ICMPv4"
          ip6 nexthdr icmpv6 accept comment "ICMPv6"

          iifname $WAN tcp dport { 80, 443 } accept comment "nginx / ACME"
          iifname $WAN udp dport 53 accept comment "DNS (falls exponiert)"
          iifname $WAN udp dport 52342 accept comment "WireGuard Hub"
          iifname $WAN udp dport 4445 accept comment "legacy UDP (ohmgraphite)"

          iifname $VPN accept comment "Dienste auf ttvpn"
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
      }

      table ip nat {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          ip saddr $VPN_NET4 oifname $WAN masquerade comment "VPN-v4 NAT"
        }
      }

      table ip6 nat {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          ip6 saddr $VPN_ULA6 oifname $WAN masquerade comment "VPN-ULA → Hetzner-v6"
        }
      }
    '';
  };
}
