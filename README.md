# Comparing SPDK and QEMU Storage Daemon for Accessing Ceph Block Storage from Virtual Machines in an IaaS Context

Benchmarking testbed and tooling for my thesis comparing
[SPDK](https://spdk.io) vhost and the
[QEMU Storage Daemon (QSD)](https://www.qemu.org/docs/master/tools/qemu-storage-daemon.html)
as storage backends for VMs backed by Ceph RBD.

- `nix/` — NixOS testbed (hosts, modules, benchmark scenarios); each scenario
  is a full system configuration switched live via `nixos-rebuild`.
  Hosts: `recurrent` (the benchmarking host) and `binky` (the VM image)
- `benchmark/` — Nushell scripts orchestrating runs (fio or elbencho backends,
  scaling the number of VMs)

```console
./benchmark/main.nu <host> [--baseline] [--backend elbencho|fio] [--timelimit <seconds>]
```

Results are archived to `~/archive/<n>` at the end of a run.

Or run it against a remote benchmarking host — `wrapper.nu` syncs the repo
to `<host>` over SSH, starts the run as a `benchmark` systemd unit there, and
streams its logs back:

```console
./benchmark/wrapper.nu <host> [...]
./benchmark/wrapper.nu pull-results <host>   # fetch ~/archive into ./benchmark/archive
```

## Development

Nix dev shell, activated with direnv:

```console
direnv allow   # or: nix-shell ./nix/shell.nix
```

## Using it

Before deploying, add your SSH keys to the `benchmark` user in
`nix/modules/user.nix`.
