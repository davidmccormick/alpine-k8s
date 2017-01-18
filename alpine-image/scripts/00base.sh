set -ux

echo "Environment is:-"
env

source /etc/os-release

cat << EOF > /etc/motd

alpine-k8s / Kubernetes Server

$PRETTY_NAME: $VERSION_ID
Docker: $DOCKER_VERSION
Kubernetes: $KUBERNETES_VERSION

See build and usage instructions at:
  <https://github.com/davidmccormick/alpine-k8s>

EOF
