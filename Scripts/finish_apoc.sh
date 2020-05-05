#!/bin/bash

# NOTE:  This particular script is/was not intended to run non-interactively.  It is the first host on my network.

PWD=`pwd`
DATE=`date +%Y%m%d`
ARCH=`uname -p`
YUM=$(which yum)

if [ `/bin/whoami` != "root" ]
then
  echo "ERROR:  You should be root to run this..."
  exit 9
fi

# Manage packages 
subscription-manager register --auto-attach
PKGS="mdadm git"
$YUM -y install $PKGS

# Disk Mirroring
parted -s /dev/sdb mklabel gpt mkpart primary ext4 2048s 100%FREE
parted -s /dev/sdc mklabel gpt mkpart primary ext4 2048s 100%FREE
mdadm --create --verbose /dev/md0 --level raid0 --raid-devices=2 /dev/sdb1 /dev/sdc1

# * * * * * * * * * * * *
# If there is already a crypttab, update it... otherwise, create a new one
if [ -f /etc/crypttab ]
then
  sed -i -e '1i# <target name>    <source device>        <key file>    <options>' /etc/crypttab
else
  echo "# <target name>    <source device>        <key file>    <options> " > /etc/crypttab
fi
sed -i -e 's/none/\/root\/.keyfile/g' /etc/crypttab

# This is a work-around until I get my network-based LUKS enabled
dd if=/dev/random of=/root/.keyfile bs=512 
cat << EOF > /etc/dracut.conf.d/10_include-keyfile.conf
# dracut modules to omit
# https://bugzilla.redhat.com/show_bug.cgi?id=905683
omit_dracutmodules+="systemd"

# dracut modules to add to the default
add_dracutmodules+="lvm crypt"

install_items="/root/.keyfile /etc/crypttab"
EOF
cryptsetup luksFormat /dev/md0
cryptsetup luksAddKey /dev/md0 /root/.keyfile 
cryptsetup --key-file /root/.keyfile luksOpen /dev/md0 DATA
BLKID=$(blkid /dev/md0 | awk '{print $2 }')
echo "DATA ${BLKID} /root/.keyfile luks" >> /etc/crypttab
mkfs.xfs /dev/mapper/DATA
mkdir /data
cp /etc/fstab /etc/fstab.orig
echo "/dev/mapper/DATA /data xfs rw,nosuid,nodev,relatime,nofail 1 2" >> /etc/fstab
mount -a
mkdir /data/{images,Projects}

# Manage NTP
LINENUM=$(grep -n "#allow 192.168.0.0" /etc/chrony.conf | cut -f1 -d\:)
sed -i -e "${LINENUM}iallow 10.10.10.0\/24" /etc/chrony.conf
systemctl enable --now chronyd; systemctl start chronyd;
#chronyd -q 'pool 0.rhel.pool.ntp.org iburst';
chronyc -a 'burst 4/4'; sleep 10; chronyc -a makestep; sleep 2; hwclock --systohc; chronyc sources

# Manage Filesystems/Directories and Storage
mkdir -p /var/lib/libvirt/images
echo "# BIND mounts" >> /etc/fstab
echo "/data/images /var/lib/libvirt/images none bind,defaults 0 0" >> /etc/fstab
mount -a

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

