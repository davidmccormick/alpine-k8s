#!/bin/bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "Running kubeadm join to configure kubernetes..."
echo "cluster_token is ${KUBE_TOKEN}"
echo kubeadm join --token "${KUBE_TOKEN}" $(cat /etc/hosts | grep master | awk '{print $1}')
kubeadm join --token "${KUBE_TOKEN}" $(cat /etc/hosts | grep master | awk '{print $1}')

#copy kubeconfig for root's usage
mkdir -p /root/.kube
cp /etc/kubernetes/kubelet.conf /root/.kube/config

# Remove kubelet restarter
[[ -f "/etc/periodic/1min/kubelet" ]] && rm -f /etc/periodic/1min/kubelet
rc-service kubelet restart


