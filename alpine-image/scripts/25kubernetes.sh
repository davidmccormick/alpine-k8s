set -eux


#echo "Downloading Kubernetes Binaries from local http server"
#echo ""
#echo "kubeadm: $KUBEADM_URL"
#curl -s -k $KUBEADM_URL >/usr/local/bin/kubeadm
#echo "kubelet: http://${HTTP_SERVER}:${HTTP_PORT}/kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/kubelet"
#curl -s -k "http://${HTTP_SERVER}:${HTTP_PORT}/kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/kubelet" >/usr/local/bin/kubelet
#echo "kubectl: http://${HTTP_SERVER}:${HTTP_PORT}/kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/kubectl"
#curl -s -k "http://${HTTP_SERVER}:${HTTP_PORT}/kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/kubectl" >/usr/local/bin/kubectl

chmod +x /usr/local/bin/kubelet /usr/local/bin/kubectl

exit 0

