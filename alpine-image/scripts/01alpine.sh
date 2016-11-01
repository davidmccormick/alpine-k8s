set -ux

echo "Setting up remote repositories..."
cat >/etc/apk/repositories <<EOT
http://liskamm.alpinelinux.uk/edge/main/
http://liskamm.alpinelinux.uk/edge/community/
EOT


echo "Performing an update/upgrade"
apk update
apk upgrade
apk add bash util-linux findutils grep

exit 0
