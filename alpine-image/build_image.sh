#!/bin/bash

set -e

# Start the packer job to create our new alpine image

# builds the latest alpine
ALPINE_LATEST_ISO=$(curl -k -s  http://dl-cdn.alpinelinux.org/alpine/.latest.x86_64.txt | head -1 | awk '{print $3}')
ALPINE_LATEST_SHA256=$(curl -k -s  http://dl-cdn.alpinelinux.org/alpine/.latest.x86_64.txt | head -1 | awk '{print $6}')

packer inspect alpine-kubernetes.json
echo ""
echo "Where: -"
echo "ALPINE_LASTEST_ISO = ${ALPINE_LATEST_ISO}"
echo "ALPINE_LATEST_SHA256 = ${ALPINE_LATEST_SHA256}"
echo ""
packer build \
 -var alpine_iso="http://dl-cdn.alpinelinux.org/alpine/${ALPINE_LATEST_ISO}"  \
 -var alpine_sha="${ALPINE_LATEST_SHA256}"  \
alpine-kubernetes.json

