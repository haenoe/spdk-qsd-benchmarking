{ lib, ... }:
{
  imports = [
    ../../modules/minimize.nix
    ../../modules/benchmark
    ./disko.nix
    ./shared.nix
  ];

  nixpkgs.flake = {
    setNixPath = lib.mkForce true;
    setFlakeRegistry = lib.mkForce true;
  };

  hardware.enableRedistributableFirmware = true;
}
