#! /usr/bin/env nu

##! /usr/bin/env nix-shell
##! nix-shell -i nushell --packages perf sysstat elbencho iperf ceph

use ./baseline.nu run-baseline
use ./benchmark.nu run-benchmark
use ./shared.nu *

use std/log

alias nixos-rebuild = ^sudo nixos-rebuild --no-reexec --no-link --show-trace --use-substitutes

def finish --env [] {
    let archive = $"($env.HOME)/archive"
    mkdir $archive

    let last = (
        ls $archive
        | get name
        | path basename
        | into int
        | sort
        | last
    )
    let iteration = ($last | default 0) + 1

    mv (results-dir) $"($archive)/($iteration)"

    log info $"Results archived to ($archive)/($iteration)"
}

def main [host: string, --timelimit: int = $DEFAULT_TIMELIMIT, --baseline, --backend: string = "elbencho"] {
    # NOTE: Stop the units to ensure that /dev/hugepages can be unmounted (and is not used by SPDK for example)
    retry {
        ^sudo systemctl stop "vm-*"
        ^sudo systemctl stop "spdk*" "qsd*"
    }

    if $baseline {
        retry { nixos-rebuild switch --file $"($env.HOME)/nix/scenarios" --attr base }

        run-baseline $timelimit
    }

    # NOTE: Like NixOS specializations this consumes _lots of_ RAM, because all
    # system configs are evaluated in one go.
    # Another approach would be `nix eval`ing the file to get the derivation
    # paths and then looping over them and building them one by one.
    let scenario_closures = ^nix build --file ~/nix/scenarios/toplevel.nix --no-link --json | from json

    let gc_roots = "/nix/var/nix/gcroots/benchmark"
    ^sudo mkdir -p $gc_roots

    $scenario_closures | each { ^sudo ln -sf $in.outputs.out $gc_roots }

    let total = ($scenario_closures | length) * ($SCALING_CONFIGURATIONS | length)
    mut i = 1

    for $scenario in $scenario_closures {
        retry { nixos-rebuild switch --store-path $scenario.outputs.out }

        let scenario_info = (
            $scenario.outputs.out
            | parse --regex '^\/nix\/store\/\w{32}-nixos-system-unnamed-(?<flavor>spdk|qsd)-(?<name>[\w-]+)$'
            | get 0
        )

        for $num_vms in $SCALING_CONFIGURATIONS {
            log info $"Starting scenario ($scenario_info.name) with storage client ($scenario_info.flavor) and ($num_vms) VMs"

            let start = date now

            run-benchmark $scenario_info.flavor $scenario_info.name $num_vms $timelimit --backend $backend

            let runtime = (date now) - $start

            log info $"Done after ($runtime). [($i)/($total)]"
            $i = $i + 1
        }
    }

    ^sudo rm -r $gc_roots

    finish
}
