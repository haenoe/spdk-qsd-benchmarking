{ lib, ... }:
{
  imports = [
    ../../modules/server.nix
    ../../modules/nix.nix
    ../../modules/user.nix
    ./networking.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
  };

  # NOTE: match the number of CPUs on the host (creates more nixbld users)
  nix.settings.max-jobs = 256;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "26.11";
}
