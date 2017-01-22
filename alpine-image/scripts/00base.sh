set -ux

echo "Environment is:-"
env

source /etc/os-release

cat << EOT > /etc/motd

alpine-k8s / Kubernetes Server

Alpine: ${VERSION_ID}
Docker: ${DOCKER_VERSION}
Kubernetes: ${KUBERNETES_VERSION}

See build and usage instructions at:
  <https://github.com/davidmccormick/alpine-k8s>

EOT
