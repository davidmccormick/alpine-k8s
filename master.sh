#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "Running kubeadm init to configure kubernetes..."
master_ip=$(cat /etc/hosts | grep $(hostname) | awk '{print $1}')
echo "master_ip is ${master_ip}"
echo "cluster_token is ${KUBE_TOKEN}"
echo "Running: kubeadm init --api-advertise-addresses=${master_ip} --api-external-dns-names=master.example.com --token=${KUBE_TOKEN}"
kubeadm init --api-advertise-addresses=${master_ip} --api-external-dns-names=master.example.com --token=${KUBE_TOKEN} | tee /root/kubeadm_init.log

#copy kubeconfig for root's usage
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

echo "Patching the apiserver manifest to advertise the master on the right address..."
sed -e 's/"--allow-privileged",/"--allow-privileged","--advertise-address='${master_ip}'",/' -i /etc/kubernetes/manifests/kube-apiserver.json
#echo "Killing to api-server so that it will re-spawn with new settings..."
#api_container=$(docker ps | grep "apiserver" | awk '{print $1}')
#docker stop ${api_container} 
#docker rm ${api_container} 

echo "Download canal setup..."
curl -k https://raw.githubusercontent.com/tigera/canal/master/k8s-install/kubeadm/canal.yaml >/root/canal.yaml
sed -e 's/100.78.232.136/100.64.0.2/' -i /root/canal.yaml
sed -e 's/canal_iface: ""/canal_iface: "eth1"/' -i /root/canal.yaml
echo "Setting up canal..."
kubectl create -f /root/canal.yaml
echo "Allowing calico policy controller and configure-canal pods to run on the master.."
kubectl annotate pod -l job-name=configure-canal -n kube-system scheduler.alpha.kubernetes.io/tolerations='[{"key":"dedicated", "operator":"Exists"}]'
kubectl annotate pod -l k8s-app=calico-policy -n kube-system scheduler.alpha.kubernetes.io/tolerations='[{"key":"dedicated", "operator":"Exists"}]'

# Remove kubelet restarter
[[ -f "/etc/periodic/1min/kubelet" ]] && rm -f /etc/periodic/1min/kubelet

