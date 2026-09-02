let
  sources = import ../npins;

  inherit (sources) disko;
  inherit (nixpkgs) lib;

  nixpkgs = import sources.nixpkgs {
    system = "x86_64-linux";
    overlays = [
      (_: prev: {
        elbencho = prev.callPackage ../packages/elbencho { };
        fio = prev.fio.overrideAttrs (prev': {
          buildInputs =
            prev'.buildInputs
            ++ (with prev; [
              libceph
              ceph-dev
            ]);
        });
        spdk =
          let
            dpdk' = prev.dpdk.overrideAttrs (prev': {
              version = "25.11";
              src = prev'.src.overrideAttrs { hash = "sha256-UukNKlMe897QKDvZGryUmAaY8fZHH6CWWKAhfPZglSY="; };
            });
          in
          (prev.spdk.override { dpdk = dpdk'; }).overrideAttrs (prev': {
            buildInputs = prev'.buildInputs ++ (with prev; [ ceph ]);
            configureFlags = prev'.configureFlags ++ [ "--with-rbd" ];
          });
      })
    ];
  };

  spdk = lib.mapAttrs' (n: v: lib.nameValuePair ("spdk-" + n) v) (import ./spdk.nix);
  qsd = lib.mapAttrs' (n: v: lib.nameValuePair ("qsd-" + n) v) (import ./qsd.nix);

  scenarioModules = spdk // qsd;

  baseImports = [
    (disko + "/module.nix")
    ./base.nix
    ../../nix/hosts/recurrent
  ];

  base = nixpkgs.nixos { imports = baseImports; };

  mtu1500 = nixpkgs.nixos {
    imports = baseImports ++ [
      ({ lib, ... }: { systemd.network.networks."99-default".linkConfig.MTUBytes = lib.mkForce 1500; })
    ];
  };

  mtu9100 = base;

  scenarios = (
    builtins.mapAttrs (
      name: module:
      (nixpkgs.nixos {
        imports = baseImports ++ [
          module
          { benchmark.scenario = { inherit name; }; }
        ];
      })
    ) scenarioModules
  );
in
scenarios
// {
  inherit
    base
    mtu1500
    mtu9100
    ;

  scenarios = builtins.attrValues scenarios;
}
