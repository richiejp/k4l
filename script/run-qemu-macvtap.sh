#!/bin/sh -eu

vm_img=$1
tap=/dev/$2

sudo chown rich $tap

qemu-system-x86_64 \
        -enable-kvm -m 4G -smp 4 \
        -nographic \
        -display none \
        -serial mon:stdio \
        -drive if=virtio,cache=unsafe,file=$vm_img \
        -netdev tap,id=tap0,fd=3 \
        -device virtio-net-pci,mac=7e:d4:dd:95:12:ad,netdev=tap0 \
        -device virtio-rng-pci \
        -device virtio-serial \
        3<>$tap
