let
  base = { lib, ... }: {
    imports = [ ./base.nix ];

    benchmark.spdk = {
      enable = true;
      allocator = lib.mkDefault "glibc";
      clusters = lib.mkDefault 16;
      numaScheduling.enable = true;
    };
  };

  cores = {
    "1-pinned-core" = { ... }: {
      imports = [ base ];
      benchmark.spdk.vhost.lcores = "(0-0)@(0-0)";
    };
    "2-pinned-cores" = { ... }: {
      imports = [ base ];
      benchmark.spdk.vhost.lcores = "(0-1)@(0-1)";
    };
    "4-pinned-cores" = { ... }: {
      imports = [ base ];
      benchmark.spdk.vhost.lcores = "(0-3)@(0-3)";
    };
  };

  clusters = {
    "16-clusters" = { ... }: {
      imports = [ cores.${"4-pinned-cores"} ];
      benchmark.spdk.clusters = 16;
    };
    "8-clusters" = { ... }: {
      imports = [ cores.${"4-pinned-cores"} ];
      benchmark.spdk.clusters = 8;
    };
    "4-clusters" = { ... }: {
      imports = [ cores.${"4-pinned-cores"} ];
      benchmark.spdk.clusters = 4;
    };
    "2-clusters" = { ... }: {
      imports = [ cores.${"4-pinned-cores"} ];
      benchmark.spdk.clusters = 2;
    };
    "1-cluster" = { ... }: {
      imports = [ cores.${"4-pinned-cores"} ];
      benchmark.spdk.clusters = 1;
    };
  };

  misc1 = {
    "jemalloc" = { ... }: {
      imports = [ clusters.${"16-clusters"} ];
      benchmark.spdk.allocator = "jemalloc";
    };
    "interrupt-mode" = { ... }: {
      imports = [ clusters.${"16-clusters"} ];
      benchmark.spdk.interruptMode.enable = true;
    };
    "4-virtqueues" = { ... }: {
      imports = [ clusters.${"16-clusters"} ];
      benchmark.vms.virtio.queues = {
        count = 4;
        size = 256;
      };
    };
  };

  misc2 = {
    "no-rbd-cache" = { ... }: {
      imports = [
        misc1.${"4-virtqueues"}
        misc1.${"jemalloc"}
      ];
      benchmark.ceph.rbdCache.enable = false;
    };
  };

  interrupt-mode-clusters = {
    "interrupt-mode-16-clusters" = { ... }: {
      imports = [ misc1.${"interrupt-mode"} ];
      benchmark.spdk.clusters = 16;
    };
    "interrupt-mode-8-clusters" = { ... }: {
      imports = [ misc1.${"interrupt-mode"} ];
      benchmark.spdk.clusters = 8;
    };
    "interrupt-mode-4-clusters" = { ... }: {
      imports = [ misc1.${"interrupt-mode"} ];
      benchmark.spdk.clusters = 4;
    };
    "interrupt-mode-2-clusters" = { ... }: {
      imports = [ misc1.${"interrupt-mode"} ];
      benchmark.spdk.clusters = 2;
    };
    "interrupt-mode-1-cluster" = { ... }: {
      imports = [ misc1.${"interrupt-mode"} ];
      benchmark.spdk.clusters = 1;
    };
  };
in
cores // clusters // misc1 // misc2 // interrupt-mode-clusters
