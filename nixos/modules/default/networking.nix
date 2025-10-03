{ ... }:
{
  networking.useNetworkd = true;

  systemd.network = {
    wait-online.anyInterface = true;
    config.networkConfig = {
      IPv6PrivacyExtensions = false;
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_ecn" = 1;
    "net.ipv6.conf.all.keep_addr_on_down" = 1;

    # allow tcp and udp services in all VRFs
    "net.ipv4.udp_l3mdev_accept" = 1;
    "net.ipv4.tcp_l3mdev_accept" = 1;
  };

  services.resolved = {
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=false
      Cache=no-negative
    '';
  };
}
