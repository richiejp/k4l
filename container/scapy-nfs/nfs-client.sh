#!/bin/sh -eu

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
start_nfs
/usr/bin/bash
