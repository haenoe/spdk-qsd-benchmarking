use std/log

export const BENCHMARK_CONFIGURATIONS = [
    {
        name: "throughput"
        threads: 1
        iodepth: 1
        block_size: "1M"
        size: "100G"
        io_type: "seq"
    }
    {
        name: "iops"
        threads: 1
        iodepth: 128
        block_size: "4K"
        size: "100G"
        io_type: "rand"
    }
    {
        name: "latency"
        threads: 1
        iodepth: 1
        block_size: "4K"
        size: "100G"
        io_type: "rand"
    }
    {
        name: "ceph-blog"
        threads: 1
        iodepth: 128
        block_size: "16K"
        size: "100G"
        io_type: "rand"
    }
    {
        name: "cluster-stress"
        threads: 4
        iodepth: 256
        block_size: "1M"
        size: "100G"
        io_type: "seq"
    }
]

export const SCALING_CONFIGURATIONS = [
    1
    2
    4
    8
    16
]

export const RETRY_ATTEMPTS = 10

export def --env retry [command: closure] {
    for $try in 1..$RETRY_ATTEMPTS {
        try {
            do --env $command
            return
        } catch {|e|
            log warning $"Attempt ($try)/($RETRY_ATTEMPTS) failed:"
            print $e.rendered

            sleep 5sec
        }
    }
    error make {msg: $"Command failed after ($RETRY_ATTEMPTS) attempts"}
}

export const DEFAULT_TIMELIMIT = 60

export def --env results-dir [...elements: string] {
    $env.RESULTS_BASE = ($env.RESULTS_BASE? | default (^mktemp -d | str trim))
    let result = $env.RESULTS_BASE | path join ...$elements

    mkdir $result
    $result
}

export def switch-to-scenario [name: string] {
    retry { ^sudo nixos-rebuild switch --no-reexec --no-link --show-trace --use-substitutes --file $"($env.HOME)/nix/scenarios" --attr $name  }
}
