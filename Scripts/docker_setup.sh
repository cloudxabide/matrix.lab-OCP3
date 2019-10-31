#!/bin/bash

yum -y install docker

cat << EOF > /etc/sysconfig/docker-storage-setup
VG=docker-vg
DEVS=/dev/vdb
EOF
docker-storage-setup
