#!/bin/bash

set -e

add_cluster_service_label() {
	local MANIFEST=$1

	# make sure has the kubernetes.io/cluster-service: 'true' label for addon manager to pick up
	if ! grep -q "^    kubernetes.io/cluster-service" /etc/kubernetes/addons/${MANIFEST}; then
		sed -e 's/^  labels:/  labels:\n    kubernetes.io\/cluster-service: "true"/' -i /etc/kubernetes/addons/${MANIFEST}
	fi
	if ! grep -q "^  labels:" /etc/kubernetes/addons/${MANIFEST}; then
		sed -e 's/^metadata:/metadata:\n  labels:\n    kubernetes.io\/cluster-service: "true"/' -i /etc/kubernetes/addons/${MANIFEST}
	fi
}

install_addon() {
	local URL=$1
	local MAN=$2

	echo "Downloading addon $URL..."
	curl -k -L -s ${URL} >/etc/kubernetes/addons/${MAN}
	#separate multiple objects in one 1 file into multiple manifests
	if grep -q "^---" /etc/kubernetes/addons/${MAN}; then
		local NUM_OBJECTS=$(cat /etc/kubernetes/addons/${MAN}  | grep "^---" | wc -l)

		# loop over the objects creating separate files file1.yaml file2.yaml
		local l=0
		while [ $l -le $NUM_OBJECTS ]
		do  
			local NEW_NAME=${MAN/%.yaml/$l.yaml}
			echo "Creating new addon manifest ${NEW_NAME}" 
			cat /etc/kubernetes/addons/${MAN} | awk 'BEGIN{count=0} ($0 ~ /^---/){count++;next} ( count == '$l' ){print}' >/etc/kubernetes/addons/${NEW_NAME}
			add_cluster_service_label "${NEW_NAME}"
			l=$((l+=1))
		done
		rm -f /etc/kubernetes/addons/${MAN}
	else
		add_cluster_service_label ${MAN}
	fi
}

# install the cluster with kubeadm
echo "Running kubeadm init to configure kubernetes..."
echo "MY_IP is ${MY_IP}"
echo "cluster_token is ${KUBE_TOKEN}"
echo "Running: kubeadm init --api-advertise-addresses=${MY_IP} --api-external-dns-names=$(hostname) --token=${KUBE_TOKEN}"
kubeadm init --api-advertise-addresses=${MY_IP} --api-external-dns-names=$(hostname) --token=${KUBE_TOKEN} --use-kubernetes-version ${KUBERNETES_VERSION} | tee /root/kubeadm_init.log

#copy kubeconfig for root's usage
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

echo "Patching the apiserver manifest to advertise the master on the right address..."
sed -e 's/"--allow-privileged",/"--allow-privileged","--advertise-address='${MY_IP}'",/' -i /etc/kubernetes/manifests/kube-apiserver.json

echo "Preparing Addons..."
mkdir -p /etc/kubernetes/addons

echo "Preparing canal as addon"
install_addon https://raw.githubusercontent.com/tigera/canal/master/k8s-install/kubeadm/canal.yaml canal.yaml
# change the interface to eth1
sed -e 's/canal_iface: ""/canal_iface: "eth1"/' -i /etc/kubernetes/addons/canal0.yaml

echo "Preparing Kubernetes Dashboard as addon"
install_addon https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml kubernetes-dashboard.yaml

echo "Preparing Heapster, InfluxDB and Grafana as addons"
for MANIFEST in heapster-deployment.yaml heapster-service.yaml grafana-deployment.yaml grafana-service.yaml influxdb-deployment.yaml influxdb-service.yaml
do
  install_addon "https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/${MANIFEST}" "${MANIFEST}"
done

# Install the addon manager as a direct kubelet manifest
echo "Installing Addon Manager - to install/manage addons"
curl -k -L -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/saltbase/salt/kube-addons/kube-addon-manager.yaml >/etc/kubernetes/manifests/addon-manager.yaml

# Remove kubelet restarter
[[ -f "/etc/periodic/1min/kubelet" ]] && rm -f /etc/periodic/1min/kubelet

