let
  base = { lib, ... }: {
    imports = [ ./base.nix ];

    benchmark = {
      qsd = {
        enable = true;
        allocator = lib.mkDefault "glibc";
        numaScheduling.enable = true;
      };
    };
  };

  iothreads = {
    "0-iothreads" = { ... }: {
      imports = [ base ];
      benchmark.qsd.iothreads.count = 0;
    };
    "1-iothread" = { ... }: {
      imports = [ base ];
      benchmark.qsd.iothreads.count = 1;
    };
    "2-iothreads" = { ... }: {
      imports = [ base ];
      benchmark.qsd.iothreads.count = 2;
    };
    "4-iothreads" = { ... }: {
      imports = [ base ];
      benchmark.qsd.iothreads.count = 4;
    };
  };

  misc1 = {
    "fixed-iothreads" = { ... }: {
      imports = [ iothreads.${"4-iothreads"} ];
      benchmark.qsd.iothreads.fixed = true;
    };
    "4-virtqueues" = { ... }: {
      imports = [ iothreads.${"4-iothreads"} ];
      benchmark.vms.virtio.queues = {
        count = 4;
        size = 256;
      };
    };
    "jemalloc" = { ... }: {
      imports = [ iothreads.${"4-iothreads"} ];
      benchmark.qsd.allocator = "jemalloc";
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
in
iothreads // misc1 // misc2
