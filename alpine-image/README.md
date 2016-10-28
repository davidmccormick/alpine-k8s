# Alpine - Docker - Kubernetes

* minimal linux distro

## Build notes

Build creates a virtualbox vagrant image and uploads to Atlas by default.
You must provide your atlas credentials to build, run: -

```
ATLAS_USER=dmcc ATLAS_TOKEN=xyz123etc123 ./build_image.sh [--force]
```

The build_image.sh script will automatically lookup the latest versions of:-

* Alpine Linux
* Kubernetes
* Kubeadm

It will name the box alpine-_version_-docker-_version_-kubernetes-_version_
If a box with the same versions exists the build will abort unless you specify the --force option 
which will cause it to remove the existing box and build it again.

## Usage notes

This image has been created as part of the alpine-k8s project: https://github.com/davidmccormick/alpine-k8s
You can download and run the image by: -

e.g.
```
vagrant box add alpine-3.4.5-docker-1.12.3-kubernetes-v1.4.4
vagrant init
vagrant up
```

Virtualbox Guest Additions do not build/install on v3.4 of Alpine.

* private network needs be configured as static in Vagrantfile in order to use folder sharing. If it is set to DHCP, Virtualbox will not see the address assigned to the interface, therefore, Vagrant will not be able to retrieve it to configure NFS.
* folder sharing should be configured to use NFS in Vagrantfile.
* `bash` is installed by default so `config.ssh.shell="/bin/sh"` is not necessary.

## Thanks

This image is based off of https://github.com/maier/vagrant-alpine/ which already took care of all the hard work installing alpine.
I just added the extra stuff to automatically lookup latest versions, install docker and kubernetes binaries.


Dave
