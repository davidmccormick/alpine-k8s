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

cat <<EOT >/etc/hosts
127.0.0.1	alpine-k8s.my.domain alpine-k8s localhost.localdomain localhost
10.250.250.2    master1.example.com master1
10.250.250.3    master2.example.com master2
10.250.250.4    master3.example.com master3
10.250.250.5    master4.example.com master4
10.250.250.6    master5.example.com master5
10.250.250.10   minion1.example.com minion1
10.250.250.11   minion2.example.com minion2
10.250.250.12   minion3.example.com minion3
10.250.250.13   minion4.example.com minion4
10.250.250.14   minion5.example.com minion5
10.250.250.15   minion6.example.com minion6
10.250.250.16   minion7.example.com minion7
10.250.250.17   minion8.example.com minion8
10.250.250.18   minion9.example.com minion9
10.250.250.19   minion10.example.com minion10
EOT

mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/cni/net.d

echo "Create kubelet service..."
cat >/etc/init.d/kubelet <<EOT
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

