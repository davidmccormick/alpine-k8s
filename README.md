# Kubernetes on Alpine

This is an experimental project with the goal of creating the latest kubernetes clusters using the super small and secure [Alpine Linux](https://www.alpinelinux.org/) distribution as a base.  Why only use Alpine within Docker containers?  We want our kubernetes infrastructure to be as minimal and simple as possible, right?

Configuring Kubernetes is somewhat complicated right now with a whole mix of different choices.  I really like the idea of [kubeadm](http://kubernetes.io/docs/getting-started-guides/kubeadm/) as it intends to make the setup simpler and makes extending an existing cluster really easy!  kubeadm is alpha and is lacking certain functionality right now, for example it can not create multi-master clusters, but this will change (or I'll be tempted down the of doing everything [the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

I've chosen 'Docker' as the container engine, because it is already available for Alpine as an APK package and because it does not require systemd (which Alpine happily does not use).

## Usage notes

This image has been created as part of the alpine-k8s project: https://github.com/davidmccormick/alpine-k8s You can download and run the image by: -

e.g.

```
vagrant box add dmcc/alpine-3.4.5-docker-1.12.3-kubernetes-v1.4.4
vagrant init vagrant init dmcc/alpine-3.4.5-docker-1.12.3-kubernetes-v1.4.4
vagrant up
```

Virtualbox Guest Additions do not build/install on v3.4 of Alpine.

private network needs be configured as static in Vagrantfile in order to use folder sharing. If it is set to DHCP, Virtualbox will not see the address assigned to the interface, therefore, Vagrant will not be able to retrieve it to configure NFS.
folder sharing should be configured to use NFS in Vagrantfile.
bash is installed by default so config.ssh.shell="/bin/sh" is not necessary.

## Building the Image

The 'alpine-image' folder contains all the source needed to build the alpine, add docker and compile and add kubernetes.
