{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.benchmark.qsd;

  qsdBase = pkgs.qemu-utils.override { cephSupport = true; };
  qemu =
    {
      glibc = qsdBase;
      jemalloc = qsdBase.overrideAttrs (prev: {
        configureFlags = prev.configureFlags ++ [ "--enable-malloc=jemalloc" ];
        buildInputs = prev.buildInputs ++ (with pkgs; [ jemalloc ]);
      });
      tcmalloc = qsdBase.overrideAttrs (prev: {
        configureFlags = prev.configureFlags ++ [ "--enable-malloc=tcmalloc" ];
        buildInputs = prev.buildInputs ++ (with pkgs; [ gperftools ]);
      });
    }
    .${cfg.allocator};
in
{
  options.benchmark.qsd = {
    enable = lib.mkEnableOption "qsd";
    numaScheduling.enable = lib.mkEnableOption "qsd numa scheduling";
    iothreads = {
      fixed = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      count = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };
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
    benchmark = {
      scenario.type = "qsd";
      vms =
        let
          manage = lib.getExe (
            pkgs.writers.writePython3Bin "qsd" {
              libraries = with pkgs.python3Packages; [ qemu-qmp ];
              flakeIgnore = [ "E501" ];
            } (builtins.readFile ./script.py)
          );
          flock = lib.getExe pkgs.flock;
        in
        {
          vhostDir = "/run/qsd";
          memory.hugepages.enable = false;
          extraEnvironment = {
            QMP_SOCKET = "/run/qsd/qmp.sock";
            IOTHREADS = toString cfg.iothreads.count;
            BLOCKDEV_ARGS = builtins.toJSON {
              inherit (config.benchmark.ceph) pool user conf;
              discard = "unmap";
              cache.direct = !config.benchmark.ceph.rbdCache.enable;
            };
            EXPORT_ARGS = builtins.toJSON {
              type = "vhost-user-blk";
              num-queues = config.benchmark.vms.virtio.queues.count;
              logical-block-size = config.benchmark.ceph.blockSize;
              fixed-iothread = cfg.iothreads.fixed;
            };
          };
          prepareCommand = "${flock} -x \${RUNTIME_DIRECTORY}/qsd.lock ${manage} create";
          cleanupCommand = "${flock} -x \${RUNTIME_DIRECTORY}/qsd.lock ${manage} delete";
        };
    };

    systemd.services.qsd = {
      # conflicts = [ "spdk.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "exec";

        ExecStart = /* bash */ ''
          ${lib.getExe' qemu "qemu-storage-daemon"} \
            --chardev "socket,id=qmp,path=''${RUNTIME_DIRECTORY}/qmp.sock,server=on,wait=off" \
            ${
              lib.concatStringsSep " " (
                lib.genList (n: "--object iothread,id=iothread${toString n}") config.benchmark.qsd.iothreads.count
              )
            } \
            --monitor "chardev=qmp"
        '';

        RuntimeDirectory = "qsd";
        RuntimeDirectoryMode = "0755";
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
