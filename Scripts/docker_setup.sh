#!/bin/bash

yum -y install docker

cat << EOF > /etc/sysconfig/docker-storage-setup
VG=docker-vg
DEVS=/dev/vdb
CONTAINER_ROOT_LV_NAME="docker-root-lv"
CONTAINER_ROOT_LV_SIZE="100%FREE"
CONTAINER_ROOT_LV_MOUNT_PATH="/var/lib/docker"
EOF
docker-storage-setup
