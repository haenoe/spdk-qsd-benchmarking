{ ... }:
{
  networking.hostName = "";

  # Also generates systemd configuration, which then takes precedence over
  # the `99-default` configuration below
  hardware.facter.report.hardware.network_interfaces = [ ];

  systemd.network.networks."99-default" = {
    matchConfig = {
      Name = "en*";
    };
    linkConfig = {
      MTUBytes = 9100;
    };
    networkConfig = {
      DHCP = "ipv6";
      LLDP = true;
      EmitLLDP = true;
    };
  };
}
