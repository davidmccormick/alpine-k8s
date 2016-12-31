set -ux

echo "Environment is:-"
env

source /etc/os-release

cat << EOF > /etc/motd

apline-k8s

$PRETTY_NAME ($VERSION_ID) 
with Docker ($DOCKER_VERSION)
and Kubernetes ($KUBERNETES_VERSION)

See build and usage instructions at:
  <https://github.com/davidmccormick/alpine-k8s>

EOF
