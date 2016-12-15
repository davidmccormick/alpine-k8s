#!/bin/bash

# get latest version of the kubectl command...
if [[ -z "${KUBERNETES_VERSION}" ]]; then
  KUBERNETES_VERSION=$(curl -s -k -L https://storage.googleapis.com/kubernetes-release/release/stable.txt)
fi

BINNAME="kubectl"
case $(uname -s) in
   Darwin)
     echo "Downloading for Mac OS X"
     CODEBASE="darwin"
     ;;
   Linux)
     echo "Downloading for Linux"
     CODEBASE="linux"	
     ;;
   CYGWIN*|MINGW32*|MSYS*)
     echo "Downloading for Windows/Cygwin"
     CODEBASE="windows"	
     BINNAME="kubectl.exe"
     ;;
   *)
     echo "Sorry! Can't detect the OS... you will need to manually download."
     exit 1 
     ;;
esac

echo "Downloading https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/${CODEBASE}/amd64/${BINNAME}" 
curl -L -k https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/${CODEBASE}/amd64/${BINNAME} >${BINNAME}
chmod a+x ${BINNAME}

# resolve windows paths or leave as is
resolve_path() {
  local PATH=$1
  case ${CODEBASE} in
    windows) echo "$(/usr/bin/cygpath -w $PATH)"
      ;;
    *) echo "$PATH"
      ;;
  esac
}

echo "Setting up kubeconfig file..."
vagrant ssh -c "sudo cat /etc/kubernetes/admin.conf" master1 >~/.kube/config

