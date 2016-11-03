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
# --packer-logs - increase the logging on the packer step.

set -e

FORCE="false"
ATLAS="false"
PACKER_LOGS="false"

# Where to download the Alpine ISO and Packages from.
ALPINE_MIRROR='dl-cdn.alpinelinux.org/alpine/'
# Which Kubernetes components to build
KUBERNETES_COMPONENTS="hyperkube kubectl kubelet"

# read command line args
for i in "$@"
do
case $i in
    --force) FORCE="true"
    ;;
    --atlas) ATLAS="true"
    ;;
    --packer-logs) PACKER_LOGS="true"
    ;;
    *) echo -e "\noption $i unknown\n"
       exit 1
    ;;
esac
done

echo -e "Builder for alpine-kubernetes vagrant box"
echo -e "=========================================\n"

# Check make sure we have all the bits to run...

REQUIRED="curl head awk sed tail packer docker"
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

if ! docker ps >/dev/null
then
  echo "Sorry, your user must be able to connect to docker to run this build."
  echo "This usually means adding your user to the 'docker' group and restarting docker and your shell".
  exit 1
fi

# Work out what we want to build...

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
ATLAS_BOXES="${ATLAS_BOX}"

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
  echo -e "ATLAS_BOXES  : ${ATLAS_BOXES}\n"
fi

export ALPINE_VERSION DOCKER_VERSION KUBERNETES_VERSION ALPINE_LATEST_ISO ALPINE_LATEST_SHA256 KUBELET_URL KUBECTL_URL KUBEADM_URL

#
# Functions for manipulating the Hashicorp ATLAS API
# I found this the most reliable way of making sure that my
# boxes are created publically accessible.
#

function check_atlas {
  set +e
  # check login to atlas...
  if ! curl --fail -k -s https://atlas.hashicorp.com/api/v1 \
    -X GET  \
    -H "X-Atlas-Token: ${ATLAS_TOKEN}" >/dev/null
  then
    echo -e "\nSorry, I could not connect to Hashicorp Atlas - are you username and token correct?\n"
    set -e
    return 1
  fi
  set -e
  return 0
}

function atlas_call {
  local VERB=$1
  local CALL_PATH=$2
  local EXTRAS=$3

  local CALL="curl --fail -k -s \"${CALL_PATH}\" -X ${VERB} -H \"X-Atlas-Token: ${ATLAS_TOKEN}\" ${EXTRAS} >/dev/null"
  echo "Calling $CALL"
  if ! eval $CALL
  then
    echo "ATLAS API CALL FAILED!"
    return 1
  else
    return 0
  fi
}

function atlas_box_exists {
  local BOX=$1

  atlas_call GET https://atlas.hashicorp.com/api/v1/box/dmcc/${BOX}
}

function atlas_box_create {
  local BOX=$1

  echo -e "Creating atlas box ${BOX}"
  if ! atlas_call POST https://atlas.hashicorp.com/api/v1/boxes "-d box[name]=\"${BOX}\" -d box[is_private]='false'"
  then
    echo -e "Sorry couldn't create the new box ${BOX}"
    return 1
  fi
  return 0
}

function atlas_box_delete {
  local USER=$1
  local BOX=$2

  echo -e "Deleting atlas box ${BOX}"
  if ! atlas_call DELETE https://atlas.hashicorp.com/api/v1/box/${USER}/${BOX}
  then
    echo -e "Sorry couldn't delete ${USER}'s box ${BOX}"
    return 1
  fi
  return 0
}

# Download the latest kubernetes and build kubelet and kubectl.

echo -e "\n************************************************"
echo -e "STEP 1: Kubernetes Compilation for Alpine Linux."
echo -e "************************************************\n"

KUBERNETES_BINARIES="kubernetes-${KUBERNETES_VERSION#v}/_output/local/bin/linux/amd64/"
mkdir -p ${KUBERNETES_BINARIES}
export KUBERNETES_BINARIES

echo -e "\nKubernetes binaries will be deployed from ${KUBERNETES_BINARIES}"

if [[ ! -d "kubernetes-${KUBERNETES_VERSION#v}" ]]
then
  echo -e "Downloading source: https://github.com/kubernetes/kubernetes/archive/${KUBERNETES_VERSION}.tar.gz"
  curl -k -L https://github.com/kubernetes/kubernetes/archive/${KUBERNETES_VERSION}.tar.gz >${KUBERNETES_VERSION}.tar.gz
  tar xfz ${KUBERNETES_VERSION}.tar.gz
fi

echo -e "\nDo we need to build our Kubernetes build container 'kubebuild:alpine'?"
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
else
  echo -e "kubebuild:alpine already exists, skipping!\n"
fi

# Need to build cni separately
echo "Checking for build of cni networking..."
if ! [[ -f "${KUBERNETES_BINARIES}/cni.tar.gz" ]]; then
  RETURN=${PWD}
  cd kubernetes-${KUBERNETES_VERSION#v}/build/cni
  sed -e 's/golang:[0-9.]*/kubebuild:alpine/' -i Makefile 
  make
  cd $RETURN 
  cp kubernetes-${KUBERNETES_VERSION#v}/build/cni/output/cni-amd64-*.tar.gz  ${KUBERNETES_BINARIES}/cni.tar.gz
else
  echo -e "Kubernetes cni binaries already built."
fi

echo -e "\nChecking Kubernetes Components to build:-"
for COMPONENT in ${KUBERNETES_COMPONENTS}; do
  echo -e "\nChecking if I need to build a new version of ${COMPONENT}..."
  if [[ ! -f "${KUBERNETES_BINARIES}/${COMPONENT}" ]]; then
    echo -e "Running kubebuild:alpine to build ${COMPONENT}"
    docker run -it --rm -v ${PWD}/kubernetes-${KUBERNETES_VERSION#v}:/usr/src/myapp -v /var/run/docker.sock:/var/run/docker.sock -w /usr/src/myapp kubebuild:alpine /bin/bash -c "make ${COMPONENT}"
  else
    echo -e "${COMPONENT} already exists, skipping build.\n"
  fi
done

echo -e "\n********************************************************"
echo -e "STEP 2: Alpine Linux-Docker-Kubernetes Vagrant Box Build"
echo -e "********************************************************\n"

# Which packer template are we going to use - with or without atlas upload?
if [[ "${ATLAS}" == "true" ]]; then
  PACKER_TEMPLATE="alpine-kubernetes-atlas.json"
else
  PACKER_TEMPLATE="alpine-kubernetes.json"
fi

if [[ "${ATLAS}" == "true" ]]
then
  check_atlas 
  for abox in ${ATLAS_BOXES}
  do
    # check if box exists
    if ! atlas_box_exists "${abox}"
    then
      atlas_box_create "${abox}" || exit 1
    else
      if [[ "$FORCE" == "true" ]]; then
        echo -e "Forced re-creation of box ${abox}"
        atlas_box_delete "${ATLAS_USER}" "${abox}" || exit 1
        atlas_box_create "${abox}" || exit 1
      else
        echo -e "Box ${abox} already exists."
        [[ "${FORCE}" == "true" ]] || exit 0
      fi
    fi
  done
fi

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
if [[ "${PACKER_LOGS}" == "true" ]]; then
  PACKER_LOG=1 packer build ${PACKER_TEMPLATE}
else
  packer build ${PACKER_TEMPLATE}
fi
echo -e "build_image completed ok\n"

exit 0
