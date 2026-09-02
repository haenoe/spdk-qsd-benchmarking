{
  config,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
    ../recurrent/shared.nix
  ];

  users.users.nixos.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsAXMqDMIq078qeowoLQfn1zlyoI+Zv2RDMG+s6XwwP i588211@LY6RXHHP25"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdmY6zsT3hIn8S/NAfhvOfDcCd5BINhstTamPTc/fA9 git@haenoe.party"
  ];

  boot.uki.settings.UKI.Initrd = "${config.system.build.netbootRamdisk}/initrd";
}
