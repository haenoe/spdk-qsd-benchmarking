#!/usr/bin/env nu

def env-or-flag [flag_val: any, env_key: string, --int] {
    if $flag_val != null {
        $flag_val
    } else if $int {
        $env | get $env_key | into int
    } else {
        $env | get $env_key
    }
}

def main [] {
    print "usage {tap {create|delete}, await-ssh, start}"
    exit 1
}

def "main tap create" [vm_id?: int] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let name = $"vm-($vm_id)"
    ip link show vmbr0

    let exists = (do { ip link show $name } | complete).exit_code == 0
    if $exists {
        error make {msg: $"TAP interface ($name) already exists"}
    }

    ip tuntap add dev $name mode tap
    ip link set $name master vmbr0
    ip link set $name up
}

def "main tap delete" [vm_id?: int] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let name = $"vm-($vm_id)"
    let exists = (do { ip link show $name } | complete).exit_code == 0

    if not $exists {
        print $"Link ($name) does not exist \(anymore\). Skipping"
        return
    }

    ip link delete $name
}

def "main await-ssh" [vm_id?: int] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let ip = $"192.168.249.(100 + $vm_id)"
    print $"Waiting for SSH on ($ip)"

    for _ in 1..60 {
        let result = do { ssh-keyscan -T 1 $ip } | complete
        if ($result.stdout | is-not-empty) {
            print $"SSH is available on ($ip)"
            return
        }
        sleep 1sec
    }
    error make {msg: $"SSH did not become available on ($ip)"}
}

def "main start" [
    vm_id?: int
    vhost_dir?: string
    cpus?: int
    #
    num_queues?: int
    queue_size?: int
    #
    memory_size?: string
    --hugepages
    #
    image_path?: string
    kernel_path?: string
    initrd_path?: string
    cmdline_base?: string
    #
    --numa_scheduling
] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let vhost_dir = (env-or-flag $vhost_dir "VHOST_DIR")
    let cpus = (env-or-flag $cpus "CPUS" --int)
    let num_queues = (env-or-flag $num_queues "NUM_QUEUES" --int)
    let queue_size = (env-or-flag $queue_size "QUEUE_SIZE" --int)
    let memory_size = (env-or-flag $memory_size "MEMORY_SIZE")
    let image_path = (env-or-flag $image_path "IMAGE_PATH")
    let kernel_path = (env-or-flag $kernel_path "KERNEL_PATH")
    let initrd_path = (env-or-flag $initrd_path "INITRD_PATH")
    let cmdline_base = (env-or-flag $cmdline_base "CMDLINE_BASE")

    let name = $"vm-($vm_id)"
    let ip = $"192.168.249.(100 + $vm_id)"
    let sock = $"($vhost_dir)/($name).sock"
    let disk = $"($env.RUNTIME_DIRECTORY)/($name).raw"
    let cmdline = $"($cmdline_base) systemd.hostname=($name) ip=($ip)::192.168.249.1:255.255.255.0:($name):eth0:none"
    let memory = $"size=($memory_size),shared=on(if $hugepages { ",hugepages=on" })"

    ^cp --reflink=auto $image_path $disk
    chmod u+w $disk

    mut args = [
        --kernel
        $kernel_path
        --initramfs
        $initrd_path
        --disk
        $"path=($disk),image_type=raw"
        --disk
        $"vhost_user=true,socket=($sock),num_queues=($num_queues),queue_size=($queue_size)"
        --cmdline
        $cmdline
        --net
        $"tap=($name)"
        --serial
        tty
        --console
        off
    ]

    if $numa_scheduling {
        let numa_range = $"[(($vm_id - 1) * $cpus)-(($vm_id * $cpus))]"
        let affinity = 0..<$cpus | each {|i| $"($i)@($numa_range)"} | str join ","
        $args = ($args | append [
           --cpus        $"boot=($cpus),max=($cpus),affinity=[($affinity)]"
           --memory      "size=0"
           --memory-zone $"id=mem0,($memory),host_numa_node=0"
            # --numa        "guest_numa_id=0,cpus=[0-$((cpus - 1))],memory_zones=[mem0]"
       ])
    } else {
        $args = ($args | append [
           --cpus   $"boot=($cpus),max=($cpus)"
           --memory $memory
       ])
    }

    exec cloud-hypervisor ...$args
}
