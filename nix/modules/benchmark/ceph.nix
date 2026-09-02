{
  lib,
  config,
  ...
}:
let
  cfg = config.benchmark.ceph;
in
{
  options.benchmark.ceph = {
    user = lib.mkOption {
      type = lib.types.str;
    };
    pool = lib.mkOption {
      type = lib.types.str;
    };
    size = lib.mkOption {
      type = lib.types.strMatching "[0-9]+(G|M)";
      description = "size of the created images";
    };
    conf = lib.mkOption {
      internal = true;
      type = lib.types.str;
      default = "/etc/ceph/ceph.conf";
    };
    rbdCache.enable = lib.mkEnableOption "enable the rbd cache";
    blockSize = lib.mkOption {
      type = lib.types.int;
    };
  };

  # NOTE: Have an option for toggling `rbd_disable_zero_copy_writes = false`?

  config = {
    system.etc.overlay.enable = false;
    environment.etc = {
      "ceph/ceph.conf".text = ''
        [global]
        mon_host = [2a10:afc0:e016:303::1]:6789,[2a10:afc0:e016:301::1]:6789,[2a10:afc0:e016:302::1]:6789

        [client]
        rbd_cache = ${lib.boolToString cfg.rbdCache.enable}

        [client.${cfg.user}]
        keyring = /etc/ceph/keyring
      '';
    };
  };
}
