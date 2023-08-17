#!/bin/sh -eu

setup_imports() {
        echo "Creating imports"

        for src in "$@"; do
                echo "Importing $src"

                mkdir -p $src
                chmod 777 $src
        done
}

start_nfs() {
        /sbin/rpcbind
        /usr/sbin/rpc.mountd -p 42069
        /usr/sbin/rpc.statd  -p 42070 -o 42071 -T 42072
}

stop_nfs() {
        pkill rpc.statd
        pkill rpc.mountd
        pkill rpcbind
}

trap stop_nfs SIGTERM SIGINT
setup_imports "$@"
start_nfs
/usr/bin/bash
