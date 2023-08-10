# About

TLDR; This is a collection of scripts, configs and documents for doing
some Linux kernel network tests in a k3s cluster. Starting with NFS.

See the Background section for more info.

# Setup

## VM

For the later steps an ALP K3s VM is required. K8s and *minikube*
could also work with some tweaks. As should running K3s on some other
setup.

At the time of writing there isn't a suitable public release of
ALP. SUSE insiders can use the IBS repository to download the latest
Dolomite image.

For what it is worth (considering I work for SUSE/Rancher), I found
installing K3s really easy on ALP. I just looked at the [OpenQA
test](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/lib/containers/k8s.pm#L32). The
hard parts come after that.

### MACVTAP

I use QEMU with
[MACVTAP/MACVLAN](https://developers.redhat.com/blog/2018/10/22/introduction-to-linux-interfaces-for-virtual-networking#),
so that the VMs are accessible on the network as if they were separate
physical machines. To allow host to guest communication you have to
mess with your hosts network config, but I have not had any issues
with it.

For example here is how to configure the network with `ip`:

```sh
host$ ip link add link enp0s25 name qemu0 type macvtap mode bridge
host$ ip link add link enp0s25 name host0 type macvlan mode bridge
host$ ip link set dev qemu0 address 7e:d4:dd:95:12:ad up
host$ ip link set dev host0 address 0a:12:68:8f:29:16 up
host$ ip addr add dev host0 192.168.0.167/24
host$ ip route add default via 192.168.0.1
```

It would be better to use your network manager however, for e.g. this
is my config with Wicked;

```sh
host$ sudo cat /etc/sysconfig/network/ifcfg-qemu0
STARTMODE='auto'
MACVTAP_DEVICE='enp0s25'
MACVTAP_MODE='bridge'
ZONE=home
host$ sudo cat /etc/sysconfig/network/ifcfg-host
STARTMODE='auto'
BOOTPROTO='dhcp'
MACVLAN_DEVICE='enp0s25'
MACVLAN_MODE='bridge'
ZONE=home
```

More likely you use NetworkManager which has [similar
settings](https://networkmanager.dev/docs/api/1.32.8/settings-macvlan.html).

### QEMU

I take the raw ALP image and create a QCOW2 with a 50GB space
limit. Using a lower limit won't save space.

```sh
host$ script/mk-qcow2.sh <vm-img.raw>
```

Assuming you have a suitable QCOW2 VM image you can start the VM with:

```sh
host$ script/run-qemu-macvtap.sh <vm-img.qcow2> <tap>
```

where `<tap>` is something like `tap8` which you can find using `ls
/dev/tap*`.

Once the VM starts you have a terrible serial console on stdio. We
just use this for the initial K3s install and watching the kernel log.

## ALP

Once the VM starts there is just a short setup to create a root user
and set the locale.

## K3s

In ALP we just run the preloaded K3s install script.

```sh
vm$ /usr/bin/k3s-install
vm$ systemctl reboot
```

After the reboot we can smoke test the K3s cluster.

```sh
vm$ k3s kubectl get pods --all-namespaces
NAMESPACE     NAME                                     READY   STATUS              RESTARTS   AGE
kube-system   helm-install-traefik-crd-bntwj           0/1     ContainerCreating   0          43s
kube-system   helm-install-traefik-wtz5r               0/1     ContainerCreating   0          43s
kube-system   metrics-server-648b5df564-4pvrh          0/1     ContainerCreating   0          43s
kube-system   coredns-77ccd57875-wq9pp                 1/1     Running             0          43s
kube-system   local-path-provisioner-957fdf8bc-zrkt4   1/1     Running             0          43s
```

You should also be able to connect to the VM via SSH, but not as root,
you need to create another user.

However most of what we want to do involves *kubectl* which we can use
from the host or another machine. The only requirement is that a
compatible version of kubectl is installed.

Assuming you have kubectl then copy `/etc/rancher/k3s/k3s.yaml` to
another machine. You need to edit the file to [change the server
IP](https://docs.k3s.io/cluster-access#accessing-the-cluster-from-outside-with-kubectl).

Then what I like to do is set an alias (`k3sctl`) which invokes
kubectl with the needed config.

```sh
host$ alias k3sctl 'kubectl --kubeconfig k3s.yaml'
host$ k3sctl get pods --all-namespaces
```

Make sure to setup auto-completions for kubectl as well. See
`kubectl completion --help`.

Finally note that k3s and k8s use a lot of CPU just maintaining the
cluster. Even if all that is running are the management pods. So when
you are not using it, it is best to shutdown the VM.

## Deploy and execute

To deploy the NFS server and client test we just apply the YAML.

```sh
host$ k3sctl apply -f conf/nfs.yaml
host$ k3sctl wait --for=condition=Ready deployment/nfs-server
```

This will deploy 3 pods:

- nfs-server
  - Uses scapy-repl container
  - Starts nfsd and RPC daemons
- scapy-repl
  - Uses scapy-repl container
  - Starts client daemons (but doesn't connect yet)
- bpftrace
  - Uses official bpftrace container
  - Only starts bash

In all 3 cases the containers are started with TTYs and Bash. We can
attach to them if necessary.

```sh
host$ k3sctl attach -it deployments/scapy-repl
scapy-repl$ mount -t nfs -o nfsvers=4 server.nfs:/ /data
```

We can also exec single commands. This can be convenient when using an
alias. For example if we want to use bpftrace.

```sh
host$ alias k3strace 'kubectl --kubeconfig k3s.yaml exec deployments/bpftrace -- bpftrace'
host$ k3strace -l "tracepoint:syscalls:sys_enter_*"
```

# Background

To automate some Linux kernel network tests we need to create a
cluster of networked machines (or network namespaces) and run some
software on them. It may be possible to run all this software in
containers.

K3s/K8s (Rancher/Kubernetes) has some interesting properties; it
allows one to declaratively specify a collection network namesapces
and run containers in them. It provides DNS, DHCP, port forwarding and
health checks/coordination.

K3s can be run on multiple VMs, so if network namespaces are not
sufficient, then we can use a multinode K3s cluster. This means we
have to automate cluster creation, however the cluster can be static.

Having said that, the complication of a Kubernetes cluster would
usually dissuade me. Kernel testing is complicated enough without
introducing more moving parts. However SUSE/Rancher has chosen to
focus on containers and k3s for ALP.
