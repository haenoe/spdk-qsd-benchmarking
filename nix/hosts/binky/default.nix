{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./elbencho.nix
    ./fio.nix
    ../../modules/server.nix
    ../../modules/minimize.nix
    ../../modules/user.nix
    ./filesystem.nix
    ./image.nix
  ];

  boot.initrd.systemd.network.enable = true;

  networking.hostName = "binky";

  # Always use `eth0` as the number of the network interface
  boot.kernelParams = [
    "net.ifnames=0"
    "scsi_mod.use_blk_mq=1"
  ];

  boot.loader = {
    systemd-boot.enable = true;
    grub.enable = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "26.11";
}
