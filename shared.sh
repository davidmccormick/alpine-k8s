#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "***************************************"
echo "*       RUNNING SHARED SETUP          *"
echo "***************************************"

echo "Add /usr/local/bin to PATH"
export PATH="$PATH:/usr/local/bin"

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

my_ip=$(cat /etc/hosts | grep ${SET_HOSTNAME}) | awk '{print $1}')
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

echo "Adding /usr/local/bin and /usr/local/sbin to root's path after sudo"
sed -e 's@^Defaults.*secure_path.*$@Defaults    secure_path = /usr/local/bin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin@' -i /etc/sudoers


echo "Configure and start the kubelet..."
mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/cni/net.d
/usr/local/bin/kubelet --kubeconfig=/etc/kubernetes/kubelet.conf --require-kubeconfig=true --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --cluster-dns=100.64.0.10 --cluster-domain=cluster.local --v=4 --hostname-override=${SET_HOSTNAME} --node-ip=${my_ip}

echo "Route Kubernetes services network 100.64.0.0/12 via eth1 by default"
route add -net 100.64.0.0/12 dev eth1

echo "***************************************"
echo "*       FINISHED SHARED SETUP         *"
echo "***************************************"

