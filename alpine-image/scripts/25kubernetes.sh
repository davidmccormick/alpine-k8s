set -eux

echo "Installing Kubeadm dependencies..."
apk add ebtables ethtool socat iproute2 iptables

echo "Downloading Kubernetes Binaries from local http server"
echo ""

chmod +x /usr/local/bin/kubeadm /usr/local/bin/hyperkube

echo "Creating hyperkube symlinks..."
cd /usr/local/bin
./hyperkube --make-symlinks

mkdir -p /opt/cni /etc/kubernetes/manifests /etc/cni/net.d
cd /opt/cni
tar xvfpz /tmp/cni.tar.gz
rm -f /tmp/cni.tar.gz

exit 0

