#!/bin/sh -eu

setup_exports() {
        echo "Creating exports"

        for src in "$@"; do
                echo "Exporting $src"

                mkdir -p $src
                chmod 777 $src
                echo "$src *(rw,sync,fsid=0,no_root_squash,no_subtree_check)" >> /etc/exports
        done
}

start_nfs() {
        mount nfsd -t nfsd /proc/fs/nfsd
        mount sunrpc -t rpc_pipefs /var/lib/nfs/rpc_pipefs

        /sbin/rpcbind
        /usr/sbin/rpc.mountd -p 42069
        /usr/sbin/rpc.statd  -p 42070 -o 42071 -T 42072

        /usr/sbin/rpc.idmapd
        /usr/sbin/nfsdcld

        /usr/sbin/exportfs -r
        /usr/sbin/rpc.nfsd -d
}

stop_nfs() {
        /usr/sbin/rpc.nfsd 0
        /usr/sbin/exportfs -auv
        /usr/sbin/exportfs -f
        pkill nfsdcld
        pkill rpc.idmapd
        pkill rpc.statd
        pkill rpc.mountd
        pkill rpcbind
}


trap stop_nfs SIGTERM SIGINT
setup_exports "$@"
start_nfs

echo "NFS Server should be ready"

/usr/bin/bash
