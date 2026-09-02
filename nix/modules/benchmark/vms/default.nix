{
  config,
  pkgs,
  # self,
  lib,
  ...
}:
let
  cfg = config.benchmark;
in
{
  options.benchmark.vms = {
    max = lib.mkOption {
      type = lib.types.number;
      default = 16;
      description = "maximum number of VMs that will be scheduled";
    };

    config = lib.mkOption {
      type = lib.types.attrs;
    };

    vhostDir = lib.mkOption {
      type = lib.types.path;
    };

    cpus = lib.mkOption {
      type = lib.types.int;
      default = 4;
    };

    prepareCommand = lib.mkOption {
      type = lib.types.str;
    };

    cleanupCommand = lib.mkOption {
      type = lib.types.str;
    };

    extraPath = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };

    memory = {
      numaScheduling.enable = lib.mkEnableOption "numa aware scheduling of vms";
      hugepages.enable = lib.mkEnableOption "active hugepages";
      sizeMib = lib.mkOption {
        type = lib.types.number;
      };
    };

    virtio.queues = {
      count = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 128;
      };
    };
  };

  config = lib.mkIf (cfg.qsd.enable || cfg.spdk.enable) {
    systemd.services."vm@" =
      let
        rbd = lib.getExe' pkgs.ceph "rbd -p ${cfg.ceph.pool} --id ${cfg.ceph.user}";
        manage = "${lib.getExe pkgs.nushell} ${./script.nu}";
      in
      {
        after = [
          "network-online.target"
          "${cfg.scenario.type}.service"
        ];
        wants = [ "network-online.target" ];

        bindsTo = [ "${cfg.scenario.type}.service" ];

        path =
          with pkgs;
          [
            iproute2
            cloud-hypervisor
            openssh
          ]
          ++ cfg.vms.extraPath;

        preStart = ''
          if ${rbd} info vm-$VM_ID 2>/dev/null; then ${rbd} rm vm-$VM_ID; fi
          ${rbd} create vm-$VM_ID --size ${lib.escapeShellArg cfg.ceph.size}
        '';
        postStop = ''
          if ${rbd} info vm-$VM_ID 2>/dev/null; then ${rbd} rm vm-$VM_ID; fi
        '';

        environment =
          let
            kernelPath = "${cfg.vms.config.system.build.kernel}/${cfg.vms.config.system.boot.loader.kernelFile}";
            initrdPath = "${cfg.vms.config.system.build.initialRamdisk}/${cfg.vms.config.system.boot.loader.initrdFile}";
            imagePath = "${cfg.vms.config.system.build.image}/image.raw";
            cmdlineBase = lib.concatStringsSep " " (
              [
                "console=ttyS0"
                "init=${cfg.vms.config.system.build.toplevel}/init"
              ]
              ++ cfg.vms.config.boot.kernelParams
            );
          in
          {
            VM_ID = "%i";
            VHOST_DIR = cfg.vms.vhostDir;
            CPUS = toString cfg.vms.cpus;
            NUM_QUEUES = toString cfg.vms.virtio.queues.count;
            QUEUE_SIZE = toString cfg.vms.virtio.queues.size;
            MEMORY_SIZE = "${toString cfg.vms.memory.sizeMib}M";
            IMAGE_PATH = imagePath;
            KERNEL_PATH = kernelPath;
            INITRD_PATH = initrdPath;
            CMDLINE_BASE = cmdlineBase;
          }
          // cfg.vms.extraEnvironment;

        serviceConfig = {
          Type = "exec";

          ExecStartPre = lib.mkAfter [
            cfg.vms.prepareCommand
            "${manage} tap create"
          ];

          # ${lib.optionalString cfg.vms.memory.numaScheduling.enable "" "--numa-scheduling"} \
          ExecStart = ''
            ${manage} start \
              ${lib.optionalString cfg.vms.memory.hugepages.enable "--hugepages"}
          '';
          ExecStartPost = "${manage} await-ssh";

          ExecStopPost = lib.mkBefore [
            # NOTE: ignore these two failures to ensure that rbd image deletion always runs
            "${manage} tap delete"
            cfg.vms.cleanupCommand
          ];

          RuntimeDirectory = "vms";
          RuntimeDirectoryMode = "700";
          # DynamicUser = true;

          LimitMEMLOCK = "infinity";
          TimeoutStartSec = "3min";

          KillMode = "mixed";
        }
        // (lib.optionalAttrs cfg.vms.memory.numaScheduling.enable {
          NUMAPolicy = "bind";
          NUMAMask = 0;
          CPUAffinity = "numa";
        });
      };
  };
}
