#!/bin/bash

set -e

FORCE="false"

# read command line args
for i in "$@"
do
case $i in
    --force) FORCE="true"
    ;;
    *) echo "option $i unknown"
       exit 1
    ;;
esac
done

echo "Builder for alpine-kubernetes vagrant box"

REQUIRED="curl head awk sed tail packer"
for BINARY in ${REQUIRED}
do
  if ! which ${BINARY} >/dev/null 2>&1; then
    echo "Sorry, this script requires ${BINARY} to run - please install through your distro."
    exit 1
  fi
done

for VAR in ATLAS_USER ATLAS_TOKEN
do
  if [[ -z $(eval "echo -n \"\$${VAR}\"") ]]; then
    echo "You must set environment variable ${VAR} before running."
    FAILED_ENV="true"
  fi
done
if [[ "${FAILED_ENV}" == "true" ]]; then
  exit 1
fi

# Start the packer job to create our new alpine image

echo "Looking up versions.."
# builds the latest alpine
ALPINE_LATEST_ISO="http://dl-cdn.alpinelinux.org/alpine/$(curl -k -s  http://dl-cdn.alpinelinux.org/alpine/.latest.x86_64.txt | head -1 | awk '{print $3}')"
ALPINE_LATEST_SHA256=$(curl -k -s  http://dl-cdn.alpinelinux.org/alpine/.latest.x86_64.txt | head -1 | awk '{print $6}')
ALPINE_VERSION="${ALPINE_LATEST_ISO%-x86_64.iso*}"
ALPINE_VERSION="${ALPINE_VERSION##*-}"

DOCKER_VERSION=$(curl -s http://dl-4.alpinelinux.org/alpine/edge/community/x86_64/ | grep "docker-[0-9]" | sed -e 's/.apk.*$//' | sed -e 's/^.*docker-//' | sed -e 's/-.*$//')

KUBERNETES_VERSION=$(curl -s -k -L https://storage.googleapis.com/kubernetes-release/release/stable.txt)
KUBELET_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubelet"
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"

KUBEADM_LATEST=$(curl -L -s https://storage.googleapis.com/kubeadm | python -c 'import sys;import xml.dom.minidom;s=sys.stdin.read();print xml.dom.minidom.parseString(s).toprettyxml()' | grep "<Key>.*amd64/kubeadm" | tail -1 | sed -e 's/^.*<Key>//' | sed -e 's/<\/Key>.*$//')
KUBEADM_URL="https://storage.googleapis.com/kubeadm/${KUBEADM_LATEST}"

ATLAS_BOX="alpine-${ALPINE_VERSION}-docker-${DOCKER_VERSION}-kubernetes-${KUBERNETES_VERSION}"

if [[ -d "output-virtualbox-iso" ]]; then
  echo "Removing existing output-virtualbox-iso"
  rm -rf output-virtualbox-iso || exit 2
fi 

echo ""
echo "Building the latest alpine Linux image with docker and kubernetes"
echo ""
echo "ALPINE_VERSION = ${ALPINE_VERSION}"
echo "DOCKER_VERSION = ${DOCKER_VERSION}"
echo "KUBERNETES_VERSION = ${KUBERNETES_VERSION}"
echo ""
echo "ALPINE_LASTEST_ISO = ${ALPINE_LATEST_ISO}"
echo "ALPINE_LATEST_SHA256 = ${ALPINE_LATEST_SHA256}"
echo "KUBELET_URL = ${KUBELET_URL}"
echo "KUBECTL_URL = ${KUBECTL_URL}"
echo "KUBEADM_URL = ${KUBEADM_URL}"
echo ""
echo "ATLAS:-"
echo "ATLAS_USER : ${ATLAS_USER}"
echo "ATLAS_TOKEN: ${ATLAS_TOKEN}"
echo "ATLAS_BOX  : ${ATLAS_BOX}"
echo ""

export ALPINE_VERSION DOCKER_VERSION KUBERNETES_VERSION ALPINE_LATEST_ISO ALPINE_LATEST_SHA256 KUBELET_URL KUBECTL_URL KUBEADM_URL

set +e
# check login to atlas...
if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1 \
  -X GET  \
  -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
then
  echo "Sorry, I could not connect to Hashicorp Atlas - are you username and token correct?"
  exit 1
fi

# check if box exists
if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/box/dmcc/${ATLAS_BOX} -X GET -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
then
  echo "Creating atlas box ${ATLAS_BOX}"
  # assume it doesn't exist and create it as a new public box
  if ! curl --fail -k -v https://atlas.hashicorp.com/api/v1/boxes -X POST -H "X-Atlas-Token: ${ATLAS_TOKEN}" -d box[name]="${ATLAS_BOX}" -d box[is_private]='false'
  then
    echo "Sorry couldn't create the new box ${ATLAS_BOX}"
    exit 1
  fi
else
  if [[ "$FORCE" == "true" ]]; then
    echo "Deleting box ${ATLAS_BOX}"
    if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/box/dmcc/${ATLAS_BOX} -X DELETE -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
    then
     echo "Failed to delete box ${ATLAS_BOX}"
     exit 1
    fi
    echo "Re-creating box ${ATLAS_BOX}"
    if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/boxes -X POST -H "X-Atlas-Token: ${ATLAS_TOKEN}" -d box[name]="${ATLAS_BOX}"  -d box[is_private]='false' >/dev/null
    then
      echo "Sorry couldn't create box ${ATLAS_BOX}"
      exit 1
    fi
  else
    echo "Box ${ATLAS_BOX} already exists."
    exit 1
  fi
fi

set -e 

echo "Writing the Vagrant file"...
cat >Vagrantfile <<EOT
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(1) do |config|

  config.vm.define "alpine" do |alpine|

    alpine.vm.box = "dmcc/${ATLAS_BOX}"

    #alpine.ssh.username = "vagrant"
    #alpine.ssh.password = "vagrant"

    # NOTE:
    #   there are *no* guest additions installed
    #   for alpine linux - the guest additions
    #   installer fails. once workarounds are
    #   identified the vbga will be added
    #   to the base box.
    #
    # since there are no vbga. if the vagrant-alpine plugin
    # is installed it can at least configure the system to
    # enable shared folders.
    #
    alpine.vm.synced_folder ".", "/vagrant", disabled: true
    #
    # after \`vagrant plugin install vagrant-alpine\`
    # comment the disabled synced_folder line above and
    # uncomment the following two lines
    #
    # alpine.vm.network "private_network", ip: "172.28.128.250"
    # alpine.vm.synced_folder ".", "/vagrant", type: "nfs"

    alpine.vm.provider "virtualbox" do |vb|
      vb.name = 'Alpine'
      vb.cpus = 1
      vb.memory = 1024
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      # Display the VirtualBox GUI when booting the machine
      # vb.gui = true
    end
  end

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

end
EOT

# build the new box
packer build alpine-kubernetes.json 
echo "build_image completed ok"
