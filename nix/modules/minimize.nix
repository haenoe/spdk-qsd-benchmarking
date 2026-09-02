{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
    (modulesPath + "/profiles/headless.nix")
  ];

  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  nixpkgs.flake = {
    setNixPath = false;
    setFlakeRegistry = false;
  };
  system.tools.nixos-option.enable = false;

  services.speechd.enable = false;
  hardware.graphics.enable = false;
  services.pipewire.enable = false;
  services.libinput.enable = false;

  # nixpkgs.overlays = [
  #   (self: super: {
  #     dbus = super.dbus.override {
  #       systemdMinimal = self.systemd;
  #     };
  #   })
  # ];
}
