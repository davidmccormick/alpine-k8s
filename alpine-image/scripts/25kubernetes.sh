set -eux

echo "Downloading Kubernetes Binaries..."
echo ""
echo "kubeadm: $KUBEADM_URL"
curl -s -k $KUBEADM_URL >/usr/local/bin/kubeadm
echo "kubelet: $KUBELET_URL"
curl -s -k $KUBELET_URL >/usr/local/bin/kubelet
echo "kubectl: $KUBECTL_URL"
curl -s -k $KUBECTL_URL >/usr/local/bin/kubectl

chmod +x /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl

exit 0

