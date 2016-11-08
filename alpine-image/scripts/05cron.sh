set -ux

echo "Adding cron check to restart kubelet.,,"
echo "*       *       *       *       *       run-parts /etc/periodic/1min" >>/etc/crontabs/root
mkdir -p /etc/periodic/1min
