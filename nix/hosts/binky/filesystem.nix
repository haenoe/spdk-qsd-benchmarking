_: {
  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = [
        "size=1G"
        "mode=755"
      ];
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/boot";
      fsType = "vfat";
    };
    "/nix/store" = {
      device = "/dev/disk/by-partlabel/nix-store";
      fsType = "squashfs";
    };
  };
}
