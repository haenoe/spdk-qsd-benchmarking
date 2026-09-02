{
  spdk,
  dpdk,
  ceph,
  ...
}:
let
  dpdk' = dpdk.overrideAttrs (prev: {
    version = "25.11";
    src = prev.src.overrideAttrs { hash = "sha256-UukNKlMe897QKDvZGryUmAaY8fZHH6CWWKAhfPZglSY="; };
  });
in
(spdk.override { dpdk = dpdk'; }).overrideAttrs (prev: {
  buildInputs = prev.buildInputs ++ [ ceph ];
  configureFlags = prev.configureFlags ++ [ "--with-rbd" ];
})
