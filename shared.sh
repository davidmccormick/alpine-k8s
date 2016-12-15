#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "Setting hostname to ${SET_HOSTNAME}"
hostname ${SET_HOSTNAME}

echo "My IP Address is $MY_IP"

echo "Setting up the private 10.250.250.0 network"
cat <<EOT >>/etc/network/interfaces
auto eth1
iface eth1 inet static
    address ${MY_IP}
    netmask 255.255.255.0
    hostname ${SET_HOSTNAME}
EOT
/etc/init.d/networking restart

echo "Route Kubernetes services network 10.96.0.0/12 via eth1 by default"
route add -net 10.96.0.0/12 dev eth1

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
  start-stop-daemon --background --start --exec /usr/local/bin/kubelet --make-pidfile --pidfile /run/kubelet.pid --stdout /var/log/kubelet.log --stderr /var/log/kubelet.log  \
  -- --require-kubeconfig --kubeconfig=/etc/kubernetes/kubelet.conf --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --cluster-dns=10.96.0.10 --cluster-domain=cluster.local --v=4 --hostname-override=${SET_HOSTNAME} --node-ip=${MY_IP} 
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

cat >/etc/periodic/1min/kubelet <<EOT
#!/bin/bash

# checks for working kubelet and tries to restart it if it does not find one.

if ! rc-service kubelet status
then
  rc-service kubelet restart
fi
EOT
chmod +x /etc/periodic/1min/kubelet

