set -eux


echo "Downloading Kubernetes Binaries from local http server"
echo ""
echo "kubeadm: $KUBEADM_URL"
curl -s -k $KUBEADM_URL >/usr/local/bin/kubeadm

chmod +x /usr/local/bin/kubeadm /usr/local/bin/hyperkube

echo "Creating hyperkube symlinks..."
cd /usr/local/bin
./hyperkube --make-symlinks

echo "Extracting kubernetes cni binaries..."
mkdir -p /opt/cni
cd /opt/cni
tar xvfpz /tmp/cni.tar.gz
rm -f /tmp/cni.tar.gz

exit 0

