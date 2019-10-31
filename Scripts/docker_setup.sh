#!/bin/bash

yum -y install docker

cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=overlay2
VG=docker-vg
DEVS=/dev/vdb
CONTAINER_ROOT_LV_NAME="docker-root-lv"
CONTAINER_ROOT_LV_SIZE="100%FREE"
CONTAINER_ROOT_LV_MOUNT_PATH="/var/lib/docker"
EOF

# If there is not a docker-vg present, then create it
vgs docker-vg || docker-storage-setup
systemctl enable docker --now
