{
  fio,
  libceph,
  ceph-dev,
  ...
}:
fio.overrideAttrs (prev: {
  buildInputs = prev.buildInputs ++ [
    libceph
    ceph-dev
  ];
})
