{ ... }:
{
  systemd.network.netdevs."10-vmbr0" = {
    netdevConfig = {
      Name = "vmbr0";
      Kind = "bridge";
    };
  };

  systemd.network.networks."10-vmbr0" = {
    matchConfig.Name = "vmbr0";
    linkConfig.RequiredForOnline = false;
    networkConfig = {
      Address = "192.168.249.1/24";
      ConfigureWithoutCarrier = true;
      # DHCPServer = true;
      IPv4Forwarding = true;
      IPMasquerade = "ipv4";
    };
  };

  networking.firewall.trustedInterfaces = [ "vmbr0" ];
}
