#!/bin/bash

# Create'a an alpine linux vagrant box with docker, kubelet, kubectl and kubeadm installed
# ready to be used.

# Copyright 2016 David McCormick
# 
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

# Options
# --force - delete and re-create an existing atlas box (default false)
# --atlas - do the atlas box pushing or not (default false)
# --local-alpine - use alpine packages mirrored in the local http server instead of remote ones. (default false)

set -e

FORCE="false"
ATLAS="false"

ALPINE_MIRROR='dl-cdn.alpinelinux.org/alpine/'

# read command line args
for i in "$@"
do
case $i in
    --force) FORCE="true"
    ;;
    --atlas) ATLAS="true"
    ;;
    --local-alpine) LOCALALPINE="true"
    ;;
    *) echo -e "\noption $i unknown\n"
       exit 1
    ;;
esac
done

# Which packer template are we going to use - with or without atlas upload?
if [[ "${ATLAS}" == "true" ]]; then
  PACKER_TEMPLATE="alpine-kubernetes-atlas.json"
else
  PACKER_TEMPLATE="alpine-kubernetes.json"
fi

echo -e "Builder for alpine-kubernetes vagrant box"
echo -e "=========================================\n"

REQUIRED="curl head awk sed tail packer"
for BINARY in ${REQUIRED}
do
  if ! which ${BINARY} >/dev/null 2>&1; then
    echo -e "Sorry, this script requires ${BINARY} to run - please install through your distro.\n"
    exit 1
  fi
done

if [[ "$ATLAS" == "true" ]]; then
  for VAR in ATLAS_USER ATLAS_TOKEN
  do
    if [[ -z $(eval "echo -n \"\$${VAR}\"") ]]; then
      echo -e "You must set environment variable ${VAR} before running.\n"
      FAILED_ENV="true"
    fi
  done
  if [[ "${FAILED_ENV}" == "true" ]]; then
    exit 1
  fi
fi

# Start the packer job to create our new alpine image

echo -n "Determining latest versions of components: "
echo -n "Alpine"
# builds the latest alpine
ALPINE_LATEST_ISO="http://${ALPINE_MIRROR}/$(curl -k -s  http://${ALPINE_MIRROR}/.latest.x86_64.txt | grep 'alpine-extended' | head -1 | awk '{print $3}')"
ALPINE_LATEST_SHA256=$(curl -k -s  http://${ALPINE_MIRROR}/.latest.x86_64.txt | grep 'alpine-extended' | head -1 | awk '{print $6}')
ALPINE_VERSION="${ALPINE_LATEST_ISO%-x86_64.iso*}"
ALPINE_VERSION="${ALPINE_VERSION##*-}"

echo -n " Docker"
DOCKER_VERSION=$(curl -s http://liskamm.alpinelinux.uk/edge/community/x86_64/ | grep "docker-[0-9]" | sed -e 's/.apk.*$//' | sed -e 's/^.*docker-//' | sed -e 's/-.*$//')

echo -n " Kubernetes"
KUBERNETES_VERSION=$(curl -s -k -L https://storage.googleapis.com/kubernetes-release/release/stable.txt)
#KUBELET_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubelet"
#KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"

echo -n " Kubeadm"
KUBEADM_LATEST=$(curl -L -s https://storage.googleapis.com/kubeadm | python -c 'import sys;import xml.dom.minidom;s=sys.stdin.read();print xml.dom.minidom.parseString(s).toprettyxml()' | grep "<Key>.*amd64/kubeadm" | tail -1 | sed -e 's/^.*<Key>//' | sed -e 's/<\/Key>.*$//')
KUBEADM_URL="https://storage.googleapis.com/kubeadm/${KUBEADM_LATEST}"
echo -e ""

ATLAS_BOX="alpine-${ALPINE_VERSION}-docker-${DOCKER_VERSION}-kubernetes-${KUBERNETES_VERSION}"

if [[ -d "output-virtualbox-iso" ]]; then
  echo -e "Removing existing output-virtualbox-iso"
  rm -rf output-virtualbox-iso || exit 2
fi 

echo -e "\nVersions:-\n"
echo -e "ALPINE_VERSION = ${ALPINE_VERSION}"
echo -e "DOCKER_VERSION = ${DOCKER_VERSION}"
echo -e "KUBERNETES_VERSION = ${KUBERNETES_VERSION}\n"
echo -e "ALPINE_LASTEST_ISO = ${ALPINE_LATEST_ISO}"
echo -e "ALPINE_LATEST_SHA256 = ${ALPINE_LATEST_SHA256}\n"
echo -e ""
if [[ "${ATLAS}" == "true" ]]; then
  echo -e "\nATLAS:-"
  echo -e "ATLAS_USER : ${ATLAS_USER}"
  echo -e "ATLAS_TOKEN: ${ATLAS_TOKEN}"
  echo -e "ATLAS_BOX  : ${ATLAS_BOX}\n"
fi

export ALPINE_VERSION DOCKER_VERSION KUBERNETES_VERSION ALPINE_LATEST_ISO ALPINE_LATEST_SHA256 KUBELET_URL KUBECTL_URL KUBEADM_URL

if [[ "${ATLAS}" == "true" ]]
then
  set +e
  # check login to atlas...
  if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1 \
    -X GET  \
    -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
  then
    echo -e "\nSorry, I could not connect to Hashicorp Atlas - are you username and token correct?\n"
    exit 1
  fi

  # check if box exists
  if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/box/dmcc/${ATLAS_BOX} -X GET -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
  then
    echo -e "Creating atlas box ${ATLAS_BOX}"
    # assume it doesn't exist and create it as a new public box
    if ! curl --fail -k -v https://atlas.hashicorp.com/api/v1/boxes -X POST -H "X-Atlas-Token: ${ATLAS_TOKEN}" -d box[name]="${ATLAS_BOX}" -d box[is_private]='false'
    then
      echo -e "Sorry couldn't create the new box ${ATLAS_BOX}"
      exit 1
    fi
  else
    if [[ "$FORCE" == "true" ]]; then
      echo -e "Deleting box ${ATLAS_BOX}"
      if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/box/dmcc/${ATLAS_BOX} -X DELETE -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
      then
       echo -e "Failed to delete box ${ATLAS_BOX}"
       exit 1
      fi
      echo -e "Re-creating box ${ATLAS_BOX}"
      if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1/boxes -X POST -H "X-Atlas-Token: ${ATLAS_TOKEN}" -d box[name]="${ATLAS_BOX}"  -d box[is_private]='false' >/dev/null
      then
        echo -e "Sorry couldn't create box ${ATLAS_BOX}"
        exit 1
      fi
    else
      echo -e "Box ${ATLAS_BOX} already exists."
      exit 1
    fi
  fi
fi

set -e 

# Download the latest kubernetes and build kubelet and kubectl.

echo -e "\n************************************************"
echo -e "STEP 1: Kubernetes Compilation for Alpine Linux."
echo -e "************************************************\n"

if [[ ! -d "kubernetes-${KUBERNETES_VERSION#v}" ]]
then
  echo -e "Downloading source: https://github.com/kubernetes/kubernetes/archive/${KUBERNETES_VERSION}.tar.gz"
  curl -k -L https://github.com/kubernetes/kubernetes/archive/${KUBERNETES_VERSION}.tar.gz >${KUBERNETES_VERSION}.tar.gz
  tar xfz ${KUBERNETES_VERSION}.tar.gz

  echo -e "Checking for our build container 'kubebuild:alpine'"
  if ! docker images | grep -e "kubebuild.*alpine"
  then
    echo -e "Building new 'kubebuild:alpine' container"
    cat >Dockerfile <<EOT
FROM golang:alpine
RUN apk update && apk add linux-headers bash grep git xz findutils which rsync coreutils alpine-sdk docker
RUN go get -u github.com/jteeuwen/go-bindata/go-bindata
ENTRYPOINT []
CMD "/bin/bash"
# Make sure the container runs as the same user as us
RUN adduser build -D -H -s /bin/bash -u $(id -u) 
RUN chown -R $(id -u) /usr/local/go /go
USER $(id -u)
EOT
    docker build . -t kubebuild:alpine
  fi

  echo -e "Building kubernetes kubelet and kubectl in docker build container kubebuild:alpine"
  docker run -it --rm -v ${PWD}/kubernetes-${KUBERNETES_VERSION#v}:/usr/src/myapp -v /var/run/docker.sock:/var/run/docker.sock -w /usr/src/myapp kubebuild:alpine /bin/bash -c "make kubelet && make kubectl"
else
  echo -e "kubectl and kubelet binaries already exist"
fi

KUBERNETES_BINARIES="kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/"
export KUBERNETES_BINARIES
echo -e "\nKubernetes binaries are here ${KUBERNETES_BINARIES}"

echo -e "\n*************************************"
echo -e "STEP 2: Alpine Linux Vagrant Box Build"
echo -e "**************************************\n"
echo -e "Writing Vagrant file"

cat >Vagrantfile <<EOT
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

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

echo -e "\nBuilding packer template ${PACKER_TEMPLATE}\n"
PACKER_LOG=1 packer build ${PACKER_TEMPLATE}
echo -e "build_image completed ok\n"

exit 0
