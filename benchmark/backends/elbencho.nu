use ../shared.nu *

export def "run-phase" [
    config: record<name: string, threads: int, iodepth: int, block_size: string, size: string, io_type: string>
    direction: string
    device: string
    results: string
    hosts: list<string>
    timelimit: int
] {
    let common_args = [
        $device
        --direct
        --block
        $config.block_size
        --size
        $config.size
        --threads
        $config.threads
        --iodepth
        $config.iodepth
        --lat
        --lathisto
        --latpercent
        --timelimit
        $timelimit
        ...(if $config.io_type == "rand" { [--rand] } else { [] })
        --infloop
        --hosts
        ($hosts | str join ",")
    ]

    let phase_args = [
        ...$common_args
        $"--($direction)"
        --jsonfile
        $"($results)/($config.name)-($direction).json"
        --csvfile
        $"($results)/($config.name)-($direction).csv"
    ]

    ^elbencho ...$phase_args
}
