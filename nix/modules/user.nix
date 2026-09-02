{ pkgs, ... }:
{
  security.sudo.wheelNeedsPassword = false;

  services.getty.autologinUser = "benchmark";

  environment.systemPackages = with pkgs; [
    carapace
    nushell
  ];

  users.users.benchmark = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # TODO: add ssh keys
    openssh.authorizedKeys.keys = [ ];
  };
}
