use ./shared.nu *
use ./backends/elbencho.nu
use ./backends/fio.nu

def pidstat-output-to-json [input_file: string, output_file: string] {
    let metrics = [
        "pct_usr"
        "pct_system"
        "pct_guest"
        "pct_wait"
        "pct_cpu"
        "cpu"
        "minflt_per_s"
        "majflt_per_s"
        "vsz"
        "rss"
        "pct_mem"
        "kb_rd_per_s"
        "kb_wr_per_s"
        "kb_ccwr_per_s"
        "iodelay"
    ]

    let parsed = (open $input_file
        | lines
        | where {|line|
            let trimmed = $line | str trim
            ($trimmed | is-not-empty) and (not ($trimmed | str starts-with "#")) and (not ($trimmed | str starts-with "Linux"))
        }
        | each {|line|
            let cols = $line | str trim | split row --regex '\s+'
            let id = if $cols.4 == "-" {
                $"($cols.20)\(($cols.3)\)"
            } else {
                $"($cols.20)\(($cols.4)\)"
            }
            {
                time: $"($cols.0) ($cols.1)",
                id: $id
                pct_usr: ($cols.5 | into float)
                pct_system: ($cols.6 | into float)
                pct_guest: ($cols.7 | into float)
                pct_wait: ($cols.8 | into float)
                pct_cpu: ($cols.9 | into float)
                cpu: ($cols.10 | into float)
                minflt_per_s: ($cols.11 | into float)
                majflt_per_s: ($cols.12 | into float)
                vsz: ($cols.13 | into float)
                rss: ($cols.14 | into float)
                pct_mem: ($cols.15 | into float)
                kb_rd_per_s: ($cols.16 | into float)
                kb_wr_per_s: ($cols.17 | into float)
                kb_ccwr_per_s: ($cols.18 | into float)
                iodelay: ($cols.19 | into float)
            }
        }
    )

    let num_slots = (
        $parsed
        | get time
        | uniq
        | length
    )

    let grouped = $parsed | group-by id

    let output = ($metrics | reduce --fold {} {|metric, acc|
        let metric_data = ($grouped | items {|thread_id, thread_rows|
            let values = $thread_rows | get $metric
            let padding = 0..<($num_slots - ($values | length)) | each {|_| 0.0}

            {key: $thread_id, value: ($padding | append $values)}
        } | reduce --fold {} {|it, rec| $rec | insert $it.key $it.value})

        $acc | insert $metric $metric_data
    })

    $output | to json | save --force $output_file
}

const PERF_FREQUENCY = 99
const PIDSTAT_INTERVAL = 1

def with-monitoring [
    pid: int
    output: string
    command: closure
    timelimit: int
] {
    let perf_results = $"($output).perf.data"
    let pidstat_intermediary_results = $"($output).pidstat.data"
    let pidstat_results = $"($output).pidstat.json"

    let perf_job = job spawn { ^sudo perf record -F $PERF_FREQUENCY -p $pid --call-graph lbr -g -o $perf_results -- sleep $timelimit }

    # Additional information that I now disabled
    # -R scheduling
    # -w context switches
    # -s stack utilization
    # -v kernel info (fds etc.)
    let pidstat_job = job spawn { ^sudo pidstat -p $pid -drtu --dec=2 -h $PIDSTAT_INTERVAL ($timelimit / $PIDSTAT_INTERVAL) o> $pidstat_intermediary_results }

    let cleanup = {
        job list | each { job kill $in.id }
    }

    try {
        do $command
    } catch {|err|
        do $cleanup

        error make $err
    }

    pidstat-output-to-json $pidstat_intermediary_results $pidstat_results

    do $cleanup
}

def benchmark [
    flavor: string
    results: string
    device: string
    hosts: list<string>
    backend: string
    timelimit: int
] {
    for $config in $BENCHMARK_CONFIGURATIONS {
        let process_name = match $flavor {
            qsd => "qemu-storage"
            spdk => "reactor_0"
        }
        let pid = ^pgrep $process_name | str trim | into int

        let fio_client_args = $hosts | each {|h| $"--client=($h)" }

        (with-monitoring
            $pid
            $"($results)/($config.name)-write"
            {
                match $backend {
                    "elbencho" => { elbencho run-phase $config "write" $device $results $hosts $timelimit }
                    "fio" => { fio run-phase $config "write" $timelimit $results --extra-args $fio_client_args --extra-job-args { ioengine: libaio, filename: $device } }
                }
            }
            $timelimit
        )

        (with-monitoring
            $pid
            $"($results)/($config.name)-read"
            {
                match $backend {
                    "elbencho" => { elbencho run-phase $config "read" $device $results $hosts $timelimit }
                    "fio" => { fio run-phase $config "read" $timelimit $results --extra-args $fio_client_args --extra-job-args { ioengine: libaio, filename: $device } }
                }
            }
            $timelimit
        )
    }
}

export def run-benchmark --env [
    flavor: string
    scenario: string
    num_vms: int
    timelimit: int
    --backend: string
] {
    let results = results-dir $"($num_vms)-vms" $flavor $scenario
    let hosts = 1..$num_vms | each {|i| $"192.168.249.(100 + $i)" }

    retry {
        ^sudo systemctl stop "vm-*"
        ^sudo systemctl stop $flavor

        let units = 1..$num_vms | each {|i| $"vm@($i)" }
        ^sudo systemctl start ...$units

        benchmark $flavor $results "/dev/vdb" $hosts $backend $timelimit
    }
}
