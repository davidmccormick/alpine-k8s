#!/bin/sh

apk add python cloud-init tzdata

echo "Configuring cloud-init service"
cat >/etc/init.d/cloud-init <<EOT
#!/sbin/openrc-run 
# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# \$Header: \$

depend() {
  need net
  need sysfs
}

start_pre() {
  ulimit -n 1048576
  return 0
}

start() {
  ebegin "Starting cloud-init"
  cloud-init init
  cloud-init modules
  eend \$?
}

stop() {
   ebegin "Stopping cloud-init"
   echo "nothing to do"
   eend 0
}
EOT

rc-update add cloud-init

