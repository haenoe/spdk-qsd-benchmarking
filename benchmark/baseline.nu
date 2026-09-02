use ./shared.nu *
use ./backends/fio.nu
use ./backends/elbencho.nu

def ceph --env [timelimit: int] {
    let results_rados = results-dir baseline ceph rados
    let results_rbd = results-dir baseline ceph rbd

    let id = "benchmark-pool-client"
    let pool = "benchmark-pool"

    for $config in $BENCHMARK_CONFIGURATIONS {
        let base_args = [
            bench
            -p
            $pool
            --id
            $id
            $timelimit
        ]

        let rados_write_args = [
            ...$base_args
            write
            --concurrent-ios
            $config.iodepth
            -b
            $config.block_size
            --no-cleanup
            --format=json-pretty
            --output
            $"($results_rados)/($config.name)-rados-write.json"
        ]

        let rados_read_args = [
            ...$base_args
            $config.io_type
            --concurrent-ios
            $config.iodepth
            --format=json-pretty
            --output
            $"($results_rados)/($config.name)-rados-read.json"
        ]

        let rados_cleanup_args = [
            cleanup
            -p
            benchmark-pool
            --id
            benchmark-pool-client
        ]

        # ^rados ...$rados_write_args
        # ^rados ...$rados_read_args
        # ^rados ...$rados_cleanup_args

        let fio_rados_job_args = {
            ioengine: rados
            clientname: $id
            pool: $pool
            conf: "/etc/ceph/ceph.conf"
        }

        fio run-phase $config "write" $timelimit $results_rados --extra-job-args $fio_rados_job_args
        fio run-phase $config "read" $timelimit $results_rados --extra-job-args $fio_rados_job_args

        let rbd_image = "benchmark-image"
        let fio_rbd_job_args = {
            ioengine: rbd
            clientname: $id
            pool: $pool
            rbdname: $rbd_image
        }

        ^rbd --id $id -p $pool rm $rbd_image | ignore
        ^rbd --id $id -p $pool create $rbd_image --size 300G

        fio run-phase $config "write" $timelimit $results_rbd --extra-job-args $fio_rbd_job_args
        fio run-phase $config "read" $timelimit $results_rbd --extra-job-args $fio_rbd_job_args

        ^rbd --id $id -p $pool rm $rbd_image
    }
}

def network --env [timelimit: int] {
    for mtu in [1500, 9100] {
        switch-to-scenario mtu($mtu)

        let results = results-dir baseline network-($mtu)

        for $scaling in $SCALING_CONFIGURATIONS {
            let out = $"($results)/($scaling)"
            mkdir $out

            for $config in ["4K", "16K", "1M"] {

                # also commented out in bash:
                for $ceph_node in ["2a10:afc0:e016:2101::1", "2a10:afc0:e016:2102::1", "2a10:afc0:e016:2103::1", "2a10:afc0:e016:2104::1"] {
                    let logfile = $"($out)/($ceph_node)-($config).json"
                    ^iperf3 --client $ceph_node --length $config --version6 --time ($timelimit / 2) --parallel $scaling --json --logfile $logfile
                }
            }
        }
    }
}

def disk --env [timelimit: int] {
    let results = results-dir baseline disk

    let hosts = ["[2a10:afc0:e016:2101::1]"]
    let device = "/dev/nvme7n1"

    # $BENCHMARK_CONFIGURATIONS

    for $config in [
    {
        name: "latency"
        threads: 1
        iodepth: 1
        block_size: "4K"
        size: "100G"
        io_type: "rand"
    }
    ] {
         elbencho run-phase $config "write" $device $results $hosts $timelimit
         elbencho run-phase $config "read" $device $results $hosts $timelimit
    }
}

export def run-baseline --env [timelimit: int] {
    # retry { network $timelimit }
    # retry { ceph $timelimit }
    retry { disk $timelimit }
}
