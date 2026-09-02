{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.benchmark.spdk;
  cephCfg = config.benchmark.ceph;
  vmCfg = config.benchmark.vms;

  hugepageSizeMib = 2;
  memorySizeMib = vmCfg.memory.sizeMib;

  hugepages = if cfg.hugepages.enable then memorySizeMib / hugepageSizeMib else 0;

  LD_PRELOAD =
    {
      glibc = null;
      tcmalloc = "${pkgs.gperftools}/lib/libtcmalloc.so";
      jemalloc = "${pkgs.jemalloc}/lib/libjemalloc.so";
    }
    .${cfg.allocator};
in
{
  options.benchmark.spdk = {
    enable = lib.mkEnableOption "spdk";

    numaScheduling.enable = lib.mkEnableOption "spdk numa scheduling";

    hugepages.enable = lib.mkEnableOption "enable hugepages" // {
      default = true;
    };

    interruptMode.enable = lib.mkEnableOption "enable interrupt mode";

    rbd = {
      coremask = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Set core mask for librbd IO context threads";
      };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "key=value configuration option for rados_conf_set (default: rely on config file)";
      };
    };
    vhost = {
      controller = {
        coremask = lib.mkOption {
          type = lib.types.str;
        };
        transport = lib.mkOption {
          type = lib.types.str;
        };
      };
      lcores = lib.mkOption {
        type = lib.types.str;
      };
    };
    clusters = lib.mkOption {
      type = lib.types.int;
    };
    allocator = lib.mkOption {
      type = lib.types.enum [
        "glibc"
        "jemalloc"
        "tcmalloc"
      ];
      default = "glibc";
    };
  };
  config = lib.mkIf cfg.enable {
    # NOTE: ensure these modules are loaded, else SPDK crashes
    boot.initrd.kernelModules = [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
    ];
    boot.kernelParams = [ "intel_iommu=on" ];

    benchmark = {
      scenario.type = "spdk";
      vms =
        let
          manage = "${lib.getExe pkgs.nushell} ${./script.nu}";
          flock = lib.getExe pkgs.flock;
        in
        {
          vhostDir = "/run/spdk";
          memory.hugepages.enable = cfg.hugepages.enable;
          extraPath = with pkgs; [
            spdk
            sysctl
          ];
          extraEnvironment = {
            RPC_SOCKET = "/run/spdk/rpc.sock";

            CLUSTERS = toString cfg.clusters;
            HUGEPAGES = toString hugepages;

            CLUSTER_USER = cephCfg.user;
            CLUSTER_CONFIG_FILE = cephCfg.conf;
            POOL = cephCfg.pool;
            BLOCK_SIZE = toString cephCfg.blockSize;
          };
          prepareCommand = "${flock} -x \${RUNTIME_DIRECTORY}/spdk.lock ${manage} create";
          cleanupCommand = "${flock} -x \${RUNTIME_DIRECTORY}/spdk.lock ${manage} delete";
        };
    };

    boot.kernel.sysctl."vm.nr_hugepages" = lib.mkIf cfg.hugepages.enable 4096;

    fileSystems."/dev/hugepages" = lib.mkIf cfg.hugepages.enable {
      fsType = "hugetlbfs";
      device = "hugetlbfs";
    };

    systemd.services.spdk = {
      # conflicts = [ "qsd.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # unitConfig.StopWhenUnneeded = true;
      environment = {
        inherit LD_PRELOAD;
      };

      path = with pkgs; [ spdk ];

      postStart = ''
        for attempt in $(seq 1 60); do
          if spdk-rpc -s "$RUNTIME_DIRECTORY/rpc.sock" spdk_get_version >/dev/null 2>&1; then
            break
          fi

          if [[ "$attempt" -eq 60 ]]; then
            echo "SPDK did not start accepting RPC connections" >&2
            exit 1
          fi

          sleep 1
        done
      '';

      serviceConfig = {
        Type = "exec";

        ExecStart = /* bash */ ''
          ${lib.getExe' pkgs.spdk "vhost"} \
            --rpc-socket ''${RUNTIME_DIRECTORY}/rpc.sock \
            -S ''${RUNTIME_DIRECTORY} \
            ${lib.optionalString (!cfg.hugepages.enable) "--no-huge --mem-size 0"} \
            ${lib.optionalString (cfg.interruptMode.enable) "--interrupt-mode"} \
            ${lib.optionalString (cfg.numaScheduling.enable) "--enforce-numa"} \
            --lcores ${cfg.vhost.lcores}
        '';

        RuntimeDirectory = "spdk";
        RuntimeDirectoryMode = "0755";

        LimitMEMLOCK = "infinity";
      }
      // lib.optionalAttrs cfg.numaScheduling.enable {
        NUMAPolicy = "bind";
        NUMAMask = 0;
        CPUAffinity = "numa";
        AllowedCPUs = "0-143";
        AllowedMemoryNodes = 0;
      };
    };
  };
}
