#!/usr/bin/env nu

def env-or-flag [flag_val, env_key: string, --int] {
    if $flag_val != null {
        $flag_val
    } else if $int {
        $env | get $env_key | into int
    } else {
        $env | get $env_key
    }
}

def cluster_name [vm_id: int, clusters: int] {
    $"benchmark-cluster-(($vm_id - 1) mod $clusters)"
}

def main [] {
    print "usage {create, delete}"
    exit 1
}

def "main create" [
    vm_id?: int
    clusters?: int
    hugepages?: int
    rpc_socket?: string
    cluster_user?: string
    cluster_config_file?: string
    pool?: string
    block_size?: int
] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let clusters = (env-or-flag $clusters "CLUSTERS" --int)
    let hugepages = (env-or-flag $hugepages "HUGEPAGES" --int)
    let rpc_socket = (env-or-flag $rpc_socket "RPC_SOCKET")
    let cluster_user = (env-or-flag $cluster_user "CLUSTER_USER")
    let cluster_config_file = (env-or-flag $cluster_config_file "CLUSTER_CONFIG_FILE")
    let pool = (env-or-flag $pool "POOL")
    let block_size = (env-or-flag $block_size "BLOCK_SIZE" --int)

    let cluster = (cluster_name $vm_id $clusters)
    let image = $"vm-($vm_id)"
    let sock = $"vm-($vm_id).sock"

    if $hugepages > 0 {
        let current = sysctl -n vm.nr_hugepages | into int
        let next = $current + $hugepages

        sysctl -w vm.nr_hugepages=($next)
    }

    let result = (
        spdk-rpc -s $rpc_socket bdev_rbd_get_clusters_info --name $cluster
        | complete
    )
    if $result.exit_code != 0 {
        spdk-rpc -s $rpc_socket bdev_rbd_register_cluster $cluster --user $cluster_user --config-file $cluster_config_file
    }

    spdk-rpc -s $rpc_socket bdev_rbd_create -b $image -c $cluster $pool $image ($block_size | into string)

    spdk-rpc -s $rpc_socket vhost_create_blk_controller --transport "vhost_user_blk" $sock $image
}

def "main delete" [
    vm_id?: int
    clusters?: int
    hugepages?: int
    rpc_socket?: string
] {
    let vm_id = (env-or-flag $vm_id "VM_ID" --int)
    let clusters = (env-or-flag $clusters "CLUSTERS" --int)
    let hugepages = (env-or-flag $hugepages "HUGEPAGES" --int)
    let rpc_socket = (env-or-flag $rpc_socket "RPC_SOCKET")

    let cluster = (cluster_name $vm_id $clusters)
    let image = $"vm-($vm_id)"
    let sock = $"vm-($vm_id).sock"

    spdk-rpc -s $rpc_socket vhost_delete_controller $sock | ignore
    spdk-rpc -s $rpc_socket bdev_rbd_delete $image | ignore

    let result = (
        spdk-rpc -s $rpc_socket bdev_rbd_get_clusters_info --name $cluster
        | complete
    )
    if $result.exit_code == 0 {
        spdk-rpc -s $rpc_socket bdev_rbd_unregister_cluster $cluster
    }

    if $hugepages > 0 {
        let current = sysctl -n vm.nr_hugepages | into int
        let next = $current - $hugepages

        sysctl -w vm.nr_hugepages=($next)
    }
}
