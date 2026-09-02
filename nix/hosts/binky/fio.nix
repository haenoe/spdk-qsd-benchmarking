{ pkgs, lib, ... }:
{
  systemd.services.fio = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.fio "fio"} --server";
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8765 ];
}
