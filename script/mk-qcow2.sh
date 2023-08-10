#!/bin/sh -eu

raw=$1
qcow2=$(basename $raw raw)qcow2

qemu-img create -f qcow2 -F raw -b $raw $qcow2 50G
