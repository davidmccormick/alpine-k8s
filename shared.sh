#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "***************************************"
echo "*       RUNNING SHARED SETUP          *"
echo "***************************************"

echo "Setting hostname to ${SET_HOSTNAME}"
hostname ${SET_HOSTNAME}

echo "Setting up /etc/hosts"
# Set up hosts file for resolution of master and minions via Vagrant private network
cat <<-EOF >/etc/hosts
127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
::1             localhost localhost.localdomain localhost6 localhost6.localdomain6
# alias kubernetes.default so that it is routeable before dns is working
10.250.250.2   master.example.com master kubernetes.default
10.250.250.10  minion01.example.com minion01
10.250.250.11  minion02.example.com minion02
10.250.250.12  minion03.example.com minion03
EOF
cat /etc/hosts

my_ip=$(cat /etc/hosts | grep ${SET_HOSTNAME} | awk '{print $1}')
echo "My IP Address is $my_ip"

echo "Setting up the private 10.250.250.0 network"
cat <<EOT >>/etc/network/interfaces
auto eth1
iface eth1 inet static
    address ${my_ip}
    netmask 255.255.255.0
    gateway 10.250.250.1
    hostname ${SET_HOSTNAME}
EOT
/etc/init.d/networking restart

echo "Route Kubernetes services network 100.64.0.0/12 via eth1 by default"
route add -net 100.64.0.0/12 dev eth1

mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/cni/net.d

echo "Create kubelet service..."
cat >/etc/init.d/kubelet <<EOT
#!/sbin/openrc-run 
# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# \$Header: \$

depend() {
  need net
  need docker
  need sysfs
}

start_pre() {
  ulimit -n 1048576
  return 0
}

start() {
  ebegin "Starting Kubelet"
  start-stop-daemon --background --start --exec /usr/local/bin/kubelet --make-pidfile --pidfile /run/kubelet.pid \
  -- --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --cluster-dns=100.64.0.10 --cluster-domain=cluster.local --v=4 --hostname-override=${SET_HOSTNAME} --node-ip=${my_ip} 
  eend \$?
}

stop() {
   ebegin "Stopping Kubelet"
   start-stop-daemon --stop --exec /usr/local/bin/kubelet --pidfile /run/kubelet.pid
   eend \$?
}
EOT
chmod +x /etc/init.d/kubelet
rc-update add kubelet
rc-service kubelet start

echo "***************************************"
echo "*       FINISHED SHARED SETUP         *"
echo "***************************************"
