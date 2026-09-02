{ lib, pkgs, ... }:
{
  benchmark = {
    ceph = {
      size = "250G";
      user = "benchmark-pool-client";
      pool = "benchmark-pool";
      blockSize = 4096;
      rbdCache.enable = lib.mkDefault false;
    };
    vms = {
      config =
        (pkgs.nixos {
          imports = [ ../hosts/binky ];
        }).config;
      memory = {
        sizeMib = 4096;
        numaScheduling.enable = lib.mkDefault true;
      };
      cpus = lib.mkDefault 4;
      virtio.queues = {
        count = lib.mkDefault 1;
        size = lib.mkDefault 128;
      };
    };
  };
}
