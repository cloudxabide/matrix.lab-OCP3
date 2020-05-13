#!/bin/bash

## PREFACE:   This script assumes you already ran post_install.sh

#########################
## DISK MANAGEMENT
#########################

# This *should* be handled by the Kickstart Profile now
raid_setup() {
# Setup the software RAID
parted -s /dev/sdb mklabel gpt mkpart pri xfs 2048s 100%
parted -s /dev/sdc mklabel gpt mkpart pri xfs 2048s 100%
parted -s /dev/sdd mklabel gpt mkpart pri xfs 2048s 100%
mdadm --create --verbose /dev/md0 --level raid0 --raid-devices=2 /dev/sdb1 /dev/sdc1 
pvcreate /dev/md0
vgcreate vg_data /dev/md0
lvcreate -nlv_data -l100%FREE vg_data
mkfs.xfs /dev/mapper/vg_data-lv_data
echo "/dev/mapper/vg_data-lv_data /data xfs defaults 0 0" >> /etc/fstab 
mkdir /data
mount -a
mkdir /data/images
echo "/data/images /var/lib/libvirt/images/ none bind,defaults 0 0" >> /etc/fstab
mount -a
restorecon -RFvv /var/lib/libvirt/images/A
}

# Manage NTP
LINENUM=$(grep -n "#allow 192.168.0.0" /etc/chrony.conf | cut -f1 -d\:)
sed -i -e "${LINENUM}iallow 10.10.10.0\/24" /etc/chrony.conf
systemctl enable --now chronyd; systemctl start chronyd;
#chronyd -q 'pool 0.rhel.pool.ntp.org iburst';
chronyc -a 'burst 4/4'; sleep 10; chronyc -a makestep; sleep 2; hwclock --systohc; chronyc sources

#####################################
#####################################
#
#     Setup Virtualization
#
#####################################
#####################################
yum -y groupinstall "Virtualization Host"
yum -y install virt-install

#####################################
#####################################
#
## NETWORK UPDATE (ADD BRIDGE)
#
#####################################
#####################################

case `hostname -s` in
  neo) IPADDR=10.10.10.11;;
  trinity) IPADDR=10.10.10.12;;
  morpheus) IPADDR=10.10.10.13;;
esac

# Configure Network Bridge
INTERFACE=eno1
CON_NAME="System $INTERFACE"
cat << EOF > /root/nmcli_cmds.sh
nmcli con add type bridge autoconnect yes con-name brkvm ifname brkvm ip4 $IPADDR/24 gw4 10.10.10.1
nmcli con modify brkvm ipv4.address $IPADDR/24 ipv4.method manual
nmcli con modify brkvm ipv4.gateway 10.10.10.1
nmcli con modify brkvm ipv4.dns "10.10.10.121"
nmcli con modify brkvm +ipv4.dns "10.10.10.122"
nmcli con modify brkvm +ipv4.dns "8.8.8.8"
nmcli con modify brkvm ipv4.dns-search "matrix.lab"
nmcli con delete "$CON_NAME"
nmcli con add type bridge-slave autoconnect yes con-name "$CON_NAME" ifname $INTERFACE master brkvm
systemctl stop NetworkManager; systemctl start NetworkManager
EOF
sh /root/nmcli_cmds.sh &

# Reboot to ensure that network update (just applied) survives a rebooT
shutdown now -r

exit 0
