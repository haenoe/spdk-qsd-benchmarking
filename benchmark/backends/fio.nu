use ../shared.nu *

def generate-jobfile [
    config: record<name: string, threads: int, iodepth: int, block_size: string, size: string, io_type: string>
    direction: string
    timelimit: int
    output_path: string
    --extra-job-args: record
] {
    let rw = match [$config.io_type, $direction] {
        ["rand", "read"] => "randread"
        ["rand", "write"] => "randwrite"
        ["seq", "read"] => "read"
        ["seq", "write"] => "write"
    }

    let jobfile = ([
        "[global]"
        "direct=1"
        $"bs=($config.block_size)"
        $"size=($config.size)"
        $"numjobs=($config.threads)"
        $"iodepth=($config.iodepth)"
        "time_based"
        $"runtime=($timelimit)"
        "lat_percentiles=1"
        "group_reporting"
        ...($extra_job_args | items {|key, value| $"($key)=($value)"})
        ""
        $"[($config.name)-($direction)]"
        $"rw=($rw)"
    ] | str join "\n")

    $jobfile | save --force $output_path
    $output_path
}

export def "run-phase" [
    config: record<name: string, threads: int, iodepth: int, block_size: string, size: string, io_type: string>
    direction: string
    timelimit: int
    results: string
    --extra-args: list<string>
    --extra-job-args: record
] {
    let jobfile_path = $"($results)/($config.name)-($direction).fio"
    let json_output = $"($results)/($config.name)-($direction).fio.json"

    generate-jobfile $config $direction $timelimit $jobfile_path --extra-job-args $extra_job_args

    (^fio
        ...$extra_args
        --output-format=json+
        $jobfile_path
        o> $json_output)
}
