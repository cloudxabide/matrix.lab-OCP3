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

# Repo/Channel Management
subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms --enable=rhel-8-for-x86_64-supplementary-rpms --enable=rhel-8-for-x86_64-appstream-rpms

# Manage (local) Users
id -u jradtke &>/dev/null || useradd -u2025 -G10 -c "James Radtke" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' jradtke
usermod -aG libvirt jradtke
usermod -aG kvm jradtke

# Manage Packages
PACKAGES="dhcp-server git httpd nmap php syslinux tftp-server "
$(which yum) -y install $PACKAGES
$(which yum) -y groupinstall "Server with GUI"
systemctl set-default graphical
yum -y update

# Manage Services (Disable)
systemctl disable cups iscsid.socket iscsi.service

# Manager Services (Enable)
SERVICES="httpd dhcpd tftp.socket tftp.service"
for SVC in $SERVICES
do
  systemctl enable --now $SVC
done

# Manage Firewall
SERVICES="dhcp ntp http"
TCP_PORTS="53 67 68 69 80"
UDP_PORTS="53 67 68 69 80"
for PORT in $TCP_PORTS
do 
  firewall-cmd --permanent --add-port=${PORT}/tcp
done
for PORT in $UDP_PORTS
do 
  firewall-cmd --permanent --add-port=${PORT}/udp
done
for SERVICE in $SERVICES
do 
  firewall-cmd --permanent --add-service=${SERVICE}
done
firewall-cmd --reload
firewall-cmd --list-all

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

#####################################
#####################################
#
#     Setup Virtualization
#
#####################################
#####################################
yum -y groupinstall "Virtualization Host"
yum -y install virt-install
# Configure Network Bridge
INTERFACE=enp0s25
cat << EOF > /root/nmcli_cmds.sh
nmcli con add type bridge autoconnect yes con-name brkvm ifname brkvm ip4 10.10.10.10/24 gw4 10.10.10.1
nmcli con modify brkvm ipv4.address 10.10.10.10/24 ipv4.method manual
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

#####################################
#####################################
#
#     Setup Kickstart 
#
#####################################
#####################################

# CREATE ISO SHARES FOR HTML
mkdir -p /var/www/OS/rhel-server-7.{5,6}-x86_64
mkdir -p /var/www/OS/rhel-8.{0,1}-x86_64
echo "/data/images/rhel-server-7.6-x86_64-dvd.iso /var/www/OS/rhel-server-7.6-x86_64 iso9660 defaults,nofail 0 0" >> /etc/fstab
echo "/data/images/rhel-8.0-x86_64-dvd.iso /var/www/OS/rhel-8.0-x86_64 iso9660 defaults,nofail 0 0" >> /etc/fstab
mount -a
restorecon -RFvv /var/www/html/

# Enable TFTP Server by updating config (disable = no) - NOTE: xinetd no longer used
#sed -i -e 's/^[ \t]\+disable[ \t]\+= yes/\tdisable\t\t\t= no/' /etc/xinetd.d/tftp
SERVICES="httpd dhcpd tftp.socket tftp.service"
for SVC in $SERVICES
do
  systemctl enable --now $SVC
  systemctl restart $SVC
done
echo "/data/tftpboot /var/lib/tftpboot none bind,defaults 0 0" >> /etc/fstab 
mount -a
restorecon -RF /var/lib/tftpboot

# Setup PXE Source
mkdir -p /var/lib/tftpboot/{efi,pxelinux.cfg,menu} /var/lib/tftpboot/rhel-server-7.{5,6}-x86_64 /var/lib/tftpboot/rhel-8.{0,1}-x86_64
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/*menu* /var/lib/tftpboot/menu/
cp -R /var/www/OS/rhel-8.0-x86_64/EFI/BOOT/* /var/lib/tftpboot/efi
#cp -R /var/www/OS/rhel-server-7.6-x86_64/EFI/BOOT/* /var/lib/tftpboot/efi
cp /var/www/OS/rhel-server-7.6-x86_64/images/pxeboot/* /var/lib/tftpboot/rhel-server-7.6-x86_64/
cp /var/www/OS/rhel-server-7.5-x86_64/images/pxeboot/* /var/lib/tftpboot/rhel-server-7.5-x86_64/
cp /var/www/OS/rhel-server-7.4-x86_64/images/pxeboot/* /var/lib/tftpboot/rhel-server-7.4-x86_64/
cp /var/www/OS/rhel-server-7.3-x86_64/images/pxeboot/* /var/lib/tftpboot/rhel-server-7.3-x86_64/
mkdir -p /var/lib/tftpboot/images/pxeboot
cp /var/www/OS/rhel-server-7.6-x86_64/images/pxeboot/* /var/lib/tftpboot/images/pxeboot

# THIS IS A BIT CONVOLUTED ... To extract the SHIM files from some RPMs
mkdir -p /var/tmp/UEFI/{x64,ia32}
find /var/www/OS/rhel-server-7.6-x86_64/ -name "shim-x*" -exec cp {} /var/tmp/UEFI/x64/ \;
find /var/www/OS/rhel-server-7.6-x86_64/ -name "grub2-efi-x64-[0-9]*" -exec cp {} /var/tmp/UEFI/x64/ \;
find /var/www/OS/rhel-server-7.6-x86_64/ -name "shim-ia32*" -exec cp {} /var/tmp/UEFI/ia32/ \;
find /var/www/OS/rhel-server-7.6-x86_64/ -name "grub2-efi-ia32-[0-9]*" -exec cp {} /var/tmp/UEFI/ia32/ \;

for DIR in /var/tmp/UEFI/x64 /var/tmp/UEFI/ia32
do
  cd $DIR
  for RPM in `ls *.rpm`
  do
    rpm2cpio $RPM | cpio -idmv
  done
done
find /var/tmp/UEFI
cp /var/tmp/UEFI/x64/boot/efi/EFI/redhat/shimx64.efi /var/lib/tftpboot/efi/
cp /var/tmp/UEFI/ia32/boot/efi/EFI/redhat/shimia32.efi /var/lib/tftpboot/efi/

restorecon -RFvv /var/lib/tftpboot/

## Setup DHCP-Server
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig
cp zion/etc_dhcp_dhcpd.conf /etc/dhcp/dhcpd.conf
systemctl restart dhcpd; systemctl status dhcpd

# Troubleshooting
# journalctl -f -u dhcpd
# tail -f /var/log/httpd/access_log
# netstat -anp | egrep 'tftp|http|dhcp'
# netstat -anp | egrep -w '67|68|69|53'

-- To view what's going on with PXE
# tcpdump -s 0 -vv port bootps
# tcpdump -i brkvm -vvv -s 1500 '((port 67 or port 68) and (udp[8:1] = 0x1))'
# https://docs.oracle.com/cd/E37670_01/E41137/html/ol-pxe-boot.html
# https://wiki.fogproject.org/wiki/index.php?title=BIOS_and_UEFI_Co-Existence



