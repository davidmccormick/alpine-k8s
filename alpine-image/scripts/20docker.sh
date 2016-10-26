set -eux

echo "adding the community repository for docker"
echo "http://mirrors.cug.edu.cn/alpine/edge/community/x86_64/" >>/etc/apk/repositories
apk update

echo "Installing docker"
apk add docker
rc-update add docker boot

echo "Disabling chroot_deny_chmod  and chroot_deny_mknod upon boot"
cat >/etc/local.d/allow_docker_pulls.start <<EOT
echo -n 0 >/proc/sys/kernel/grsecurity/chroot_deny_chmod
echo -n 0 >/proc/sys/kernel/grsecurity/chroot_deny_mknod
EOT
rc-update add local boot


