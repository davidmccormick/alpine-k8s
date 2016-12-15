#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

env

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
sleep 5
#echo "Killing to api-server so that it will re-spawn with new settings..."
#api_container=$(docker ps | grep "apiserver" | awk '{print $1}')
#docker stop ${api_container} 
#docker rm ${api_container} 

echo "Download canal setup..."
curl -k https://raw.githubusercontent.com/tigera/canal/master/k8s-install/kubeadm/canal.yaml >/root/canal.yaml
sed -e 's/canal_iface: ""/canal_iface: "eth1"/' -i /root/canal.yaml

wait_for_api_server_available() {
set +e
curl --fail -s -k -L --cacert /etc/kubernetes/pki/ca.pem --cert /etc/kubernetes/pki/apiserver.pem --key /etc/kubernetes/pki/apiserver-key.pem https://10.250.250.2:6443/api/v1
while [[ $? != 0 ]] 
do
	echo "Waiting for API Server to be available on https://${MY_IP}:6443"
	sleep 5
	curl --fail -s -k -L --cacert /etc/kubernetes/pki/ca.pem --cert /etc/kubernetes/pki/apiserver.pem --key /etc/kubernetes/pki/apiserver-key.pem https://10.250.250.2:6443/api/v1
done
set -e
}

echo "Setting up canal..."
wait_for_api_server_available
kubectl create -f /root/canal.yaml
# No longer need to do this because I changed canal yaml to include these annotations.
#echo "Allowing calico policy controller and configure-canal pods to run on the master.."
kubectl annotate --overwrite pod -l job-name=configure-canal -n kube-system scheduler.alpha.kubernetes.io/tolerations='[{"key":"dedicated", "operator":"Exists"}]'
kubectl annotate --overwrite pod -l k8s-app=calico-policy -n kube-system scheduler.alpha.kubernetes.io/tolerations='[{"key":"dedicated", "operator":"Exists"}]'

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

