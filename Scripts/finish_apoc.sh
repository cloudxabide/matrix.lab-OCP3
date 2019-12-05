#!/bin/bash

PWD=`pwd`
DATE=`date +%Y%m%d`
ARCH=`uname -p`
YUM=$(which yum)

if [ `/bin/whoami` != "root" ]
then
  echo "ERROR:  You should be root to run this..."
  exit 9
fi

# Manage NTP
LINENUM=$(grep -n "#allow 192.168.0.0" /etc/chrony.conf | cut -f1 -d\:)
sed -i -e "${LINENUM}iallow 10.10.10.0\/24" /etc/chrony.conf
systemctl enable --now chronyd; systemctl start chronyd;
#chronyd -q 'pool 0.rhel.pool.ntp.org iburst';
chronyc -a 'burst 4/4'; sleep 10; chronyc -a makestep; sleep 2; hwclock --systohc; chronyc sources

# Manage Filesystems/Directories and Storage
mkdir /data
cp /etc/fstab /etc/fstab.orig
echo "# NON-Root Mounts" >> /etc/fstab
echo "/dev/mapper/vg_data-lv_data /data xfs defaults 0 0" >> /etc/fstab
mount -a || exit 9

echo "# BIND mounts" >> /etc/fstab
echo "/data/images /var/lib/libvirt/images none bind,defaults 0 0" >> /etc/fstab
mount -a

# Manage Packages
PACKAGES="git"
yum -y install $PACKAGES

# Disable services
DISABLE_SERVICES="avahi-daemon iscsid bluetooth.service"
for SVC in $DISABLE_SERVICES
do
  systemctl disable $SVC --now
done

#####################################
#####################################
#
#     Setup Virtualization
#
#####################################
#####################################
yum -y groupinstall "Virtualization Host"
yum -y install virt-* 
# Configure Network Bridge
INTERFACE=eno1
cat << EOF > /root/nmcli_cmds.sh
nmcli con add type bridge autoconnect yes con-name brkvm ifname brkvm ip4 10.10.10.18/24 gw4 10.10.10.1
nmcli con modify brkvm ipv4.address 10.10.10.18/24 ipv4.method manual
nmcli con modify brkvm ipv4.gateway 10.10.10.1
nmcli con modify brkvm ipv4.dns "10.10.10.121"
nmcli con modify brkvm +ipv4.dns "10.10.10.122"
nmcli con modify brkvm +ipv4.dns "8.8.8.8"
nmcli con modify brkvm ipv4.dns-search "matrix.lab"
nmcli con delete $INTERFACE
nmcli con add type bridge-slave autoconnect yes con-name $INTERFACE ifname $INTERFACE master brkvm
systemctl stop NetworkManager; systemctl start NetworkManager
EOF
sh /root/nmcli_cmds.sh &

