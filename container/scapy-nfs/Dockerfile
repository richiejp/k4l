FROM registry.opensuse.org/opensuse/tumbleweed:20230724

# nfs client and network utils
RUN zypper -n in bind-utils iproute2 nfs-client
# nfs server and more utils
RUN zypper -n in yast2-nfs-server nfs-kernel-server nfswatch utils-libnfs
# Scapy deps
RUN zypper -n in python311 python311-pip libpcap-devel git-core tcpdump fish
# tracing
RUN zypper -n in strace ltrace perf wireshark

# Install Scapy
WORKDIR /root
RUN git clone --depth=1 https://github.com/secdev/scapy
WORKDIR ./scapy
RUN pip install --compile cryptography ipython
RUN pip install .

WORKDIR /root

ADD ./nfs-server.sh /usr/bin/nfs-server.sh
ADD ./nfs-client.sh /usr/bin/nfs-client.sh

# Create nobody user for nfsv4 id mapping (rpc.idmapd)
RUN groupadd -g 65534 nobody
RUN useradd -u 65534 -g 65534 -d /var/lib/nobody nobody

WORKDIR /data
VOLUME /data

CMD ["bash"]
