set -eux


echo "Downloading Kubernetes Binaries from local http server"
echo ""
echo "kubeadm: $KUBEADM_URL"
curl -s -k $KUBEADM_URL >/usr/local/bin/kubeadm

chmod +x /usr/local/bin/kubeadm /usr/local/bin/hyperkube

echo "Creating hyperkube symlinks..."
cd /usr/local/bin
./hyperkube --make-symlinks

mkdir -p /opt/cni /etc/kubernetes/manifests /etc/cni/net.d
cd /opt/cni
tar xvfpz /tmp/cni.tar.gz
rm -f /tmp/cni.tar.gz

exit 0

