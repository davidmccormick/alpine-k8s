set -ux

source /etc/os-release

cat << EOF > /etc/motd

$PRETTY_NAME ($VERSION_ID) 
$HOME_URL

with Docker ($DOCKER_VERSION)
and Kubernetes ($KUBERNETES_VERSION)

See build and usage instructions at:
  <https://github.com/davidmccormick/alpine-k8s>

EOF
