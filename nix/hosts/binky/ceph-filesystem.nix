{ pkgs, ... }:
{
  boot = {
    initrd.systemd = {
      extraBin."mkfs.ext4" = "${pkgs.e2fsprogs}/bin/mkfs.ext4";
      repart = {
        enable = true;
        device = "/dev/vdb";
        empty = "allow";
      };
    };

    initrd.supportedFilesystems.ext4 = true;
    supportedFilesystems.ext4 = true;
  };

  # Automatically partition the RBD with ext4
  systemd.repart.partitions = {
    ceph = {
      Format = "ext4";
      Label = "ceph";
      Type = "linux-generic";
      Weight = 1;
    };
  };

  fileSystems."/ceph" = {
    device = "/dev/disk/by-partlabel/ceph";
    fsType = "ext4";
  };
}
