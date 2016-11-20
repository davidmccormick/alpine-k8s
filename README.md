# Kubernetes on Alpine

Components: -
* Alpine Linux
* Docker
* Kubernetes (hyperkube, kubeadm and cni)
* Canal (Calico/Flannel) networking

This is an experimental project with the goal of creating the latest kubernetes clusters using the super small and secure [Alpine Linux](https://www.alpinelinux.org/) distribution as a base running on Vagrant.  I want to make the kubernetes footprint as small and simple as possible.

My aim is to set up our cluster __the easy way__ but should this prove to be too restrictive then I'll have to consider [the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

## Bringing up the kubernetes cluster

```
git clone https://github.com/davidmccormick/alpine-k8s
cd alpine-k8s
vagrant box add dmcc/alpine-3.4.5-docker-1.12.3-kubernetes-v1.4.4
vagrant up
```
## More information

### What do we get?

We presently install one master (master.example.com) and two minions (minion01/2.example.com).  The installation is performed by kubeadm and so most of the kubernetes components (execept kubectl, kubelet, kubeadm and cni) are downloaded and started up in their own docker containers (this is despite having hyperkube available natively inside the image) - this is because this is how kubeadm wants to work.  Having the binaries available in the image makes it more flexible and you can easily replace my provisioning scripts with your own.

* **Canal (Flannel/Calico)** is installed as an addon and interfaces into the kubelet via cni.
* **SkyDNS** is automatically* configured by kubeadm.
* The **kube-dashboard** is also added

### The Alpine-k8s vagrant image 

The job of adding the docker, kubernetes and cni binaries are taken care of wihin the build of the *alpine-x.x.x-docker-x.x.x-kubenetes-vx.x.x* image, which you can download from Atlas or build using the scripts in the **alpine-image** folder (please see the README in this folder about requirements and usage). 

### Cluster token

The cluster token is randomly generated in the Vagrantfile and saved to the file cluster-token.  This is so we can add nodes later to a running cluster.  You can generate a new cluster token by removing the cluster-token file.

### Provisioning Scripts

The **shared.sh** script sets up the networking and makes sure that the kubernetes kubelet is running by adding a cron job to restart it every 1 minute (this job is then removed again once everything is configured and running).

The **master.sh** script runs kubeadm init to set up your cluster and once available it is responsible for installing our addons such as canal networking and dashboard.

The **minion.sh** script runs kubeadm to join the cluster.

### No Rkt

I've chosen **Docker** as the container engine over Rkt, because it is already available for Alpine as an APK package and because it does not require systemd (which Alpine happily does not use).

### Dashboard

The kubernetes dashboard is installed manually but from its addon manifests.  The Vagrantfile configures the local port 8080 to be forwarded to the masters 8080 so you can view it via the URL http://localhost:8080

## Present Limitations
1. No master HA.
2. No Ingress.
3. No physical volumes.
4. No authentication or quotas.
