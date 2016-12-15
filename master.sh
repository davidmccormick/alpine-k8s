#!/bin/bash

set -e

echo "Running kubeadm init to configure kubernetes..."
echo "MY_IP is ${MY_IP}"
echo "cluster_token is ${KUBE_TOKEN}"
echo "Running: kubeadm init --api-advertise-addresses=${MY_IP} --api-external-dns-names=master.example.com --token=${KUBE_TOKEN}"
kubeadm init --api-advertise-addresses=${MY_IP} --api-external-dns-names=master.example.com --token=${KUBE_TOKEN} --use-kubernetes-version ${KUBERNETES_VERSION} | tee /root/kubeadm_init.log

#copy kubeconfig for root's usage
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

echo "Patching the apiserver manifest to advertise the master on the right address..."
sed -e 's/"--allow-privileged",/"--allow-privileged","--advertise-address='${MY_IP}'",/' -i /etc/kubernetes/manifests/kube-apiserver.json

echo "Download canal setup..."
curl -k https://raw.githubusercontent.com/tigera/canal/master/k8s-install/kubeadm/canal.yaml >/etc/kubernetes/manifests/canal.yaml
sed -e 's/canal_iface: ""/canal_iface: "eth1"/' -i /etc/kubernetes/manifests/canal.yaml

echo "Installing Addon Manager"
mkdir -p /etc/kubernetes/addons
curl -k -L -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/saltbase/salt/kube-addons/kube-addon-manager.yaml >/etc/kubernetes/manifests/addon-manager.yaml

echo "Installing Kubernetes Dashboard"
curl -L -k https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml /etc/kubernetes/addons/kubernetes-dashboard.yaml

echo "Installing heapster"
curl -k -L -s https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/standalone/heapster-controller.yaml >/etc/kubernetes/addons/heapster-controller.yaml
curl -k -L -s https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/standalone/heapster-service.yaml >/etc/kubernetes/addons/heapster-service.yaml
#echo "Installing Metric's collection..."
#curl -k -L https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/cluster-monitoring/influxdb/influxdb-service.yaml >/etc/kubernetes/addons/influxdb-service.yaml
#curl -k -L https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/cluster-monitoring/influxdb/influxdb-grafana-controller.yaml >/etc/kubernetes/addons/influxdb-grafana-controller.yaml

# Remove kubelet restarter
[[ -f "/etc/periodic/1min/kubelet" ]] && rm -f /etc/periodic/1min/kubelet

