#!/bin/bash

set -e

echo "Builder for alpine-kubernetes vagrant box"

REQUIRED="curl head awk sed tail packer"
for BINARY in ${REQUIRED}
do
  if ! which ${BINARY} >/dev/null 2>&1; then
    echo "Sorry, this script requires ${BINARY} to run - please install through your distro."
    exit 1
  fi
done

for VAR in ATLAS_USER ATLAS_BOX ATLAS_TOKEN
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

DOCKER_VERSION=$(curl -s http://dl-4.alpinelinux.org/alpine/edge/community/x86_64/ | grep "docker-[0-9]" | sed -e 's/.apk.*$//' | sed -e 's/^.*docker-//')

KUBERNETES_VERSION=$(curl -s -k -L https://storage.googleapis.com/kubernetes-release/release/stable.txt)
KUBELET_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubelet"
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"

KUBEADM_LATEST=$(curl -L -s https://storage.googleapis.com/kubeadm | python -c 'import sys;import xml.dom.minidom;s=sys.stdin.read();print xml.dom.minidom.parseString(s).toprettyxml()' | grep "<Key>.*amd64/kubeadm" | tail -1 | sed -e 's/^.*<Key>//' | sed -e 's/<\/Key>.*$//')
KUBEADM_URL="https://storage.googleapis.com/kubeadm/${KUBEADM_LATEST}"

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
export ALPINE_VERSION DOCKER_VERSION KUBERNETES_VERSION ALPINE_LATEST_ISO ALPINE_LATEST_SHA256 KUBELET_URL KUBECTL_URL KUBEADM_URL

packer build \
alpine-kubernetes.json

# -var alpine_iso="http://dl-cdn.alpinelinux.org/alpine/${ALPINE_LATEST_ISO}"  \
# -var alpine_sha="${ALPINE_LATEST_SHA256}"  \
# -var kubelet_url="${KUBELET_URL}"  \
# -var kubectl_url="${KUBECTL_URL}"  \
# -var kubeadm_url="${KUBEADM_URL}"  \
# -var alpine_version="${ALPINE_VERSION}" \
# -var docker_version="${DOCKER_VERSION}" \
# -var kubernetes_version="${KUBERNETES_VERSION}" \
#alpine-kubernetes.json

