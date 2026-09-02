{ pkgs, lib, ... }:
{
  systemd.services.elbencho = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.elbencho "elbencho"} --service --foreground";
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [ 1611 ];
}
