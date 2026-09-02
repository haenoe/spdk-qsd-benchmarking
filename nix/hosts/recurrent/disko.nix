{ config, ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme1n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "${config.networking.hostName}"
              "-f"
            ];
            subvolumes =
              let
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              in
              {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = mountOptions ++ [ "subvol=root" ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = mountOptions ++ [ "subvol=home" ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = mountOptions ++ [ "subvol=nix" ];
                };
              };
          };
        };
      };
    };
  };
}
