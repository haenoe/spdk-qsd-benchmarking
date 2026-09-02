{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.benchmark;
in
{
  imports = [
    ./ceph.nix
    ./network.nix
    ./vms
    ./qsd
    ./spdk
  ];

  options.benchmark = {
    scenario = {
      type = lib.mkOption {
        internal = true;
        type = lib.types.enum [
          "qsd"
          "spdk"
          "base"
        ];
        default = "base";
      };
      name = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !(cfg.qsd.enable && cfg.spdk.enable);
        message = "`benchmark.qsd` and `benchmark.spdk` are mutually exclusive";
      }
    ];

    system.nixos.label = lib.mkIf (cfg.qsd.enable || cfg.spdk.enable) (
      lib.mkForce "${cfg.scenario.type}:${cfg.scenario.name}"
    );

    powerManagement.cpuFreqGovernor = "performance";

    environment.systemPackages = with pkgs; [
      fio
      rsync
      retry
      python313Packages.tqdm
      iperf3
      sysstat
      elbencho
      gnuplot
      ceph
    ];
  };
}
