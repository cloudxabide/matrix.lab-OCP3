te!/bin/bash
WEBSERVER=10.10.10.10

export rhnuser=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnuser | cut -f2 -d\=)
export rhnpass=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnpass | cut -f2 -d\=)

subscription-manager status || subscription-manager register --auto-attach --force --username="${rhnuser}" --password="${rhnpass}"

# Repo/Channel Management
# subscription-manager facts --list  | grep distribution.version: | awk '{ print $2 }' <<== Alternate to gather "version"
case `cut -f5 -d\: /etc/system-release-cpe` in
  7.*)
    echo "NOTE:  detected EL7"
    subscription-manager repos --disable="*" --enable rhel-7-server-rpms
  ;;
  8.*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms
  ;;
esac

yum -y install deltarpm

#########################
## USER MANAGEMENT
#########################
# Create an SSH key/pair if one does not exist (which should be the case for a new system)
[ ! -f /root/.ssh/id_rsa ] && echo | ssh-keygen -trsa -b2048 -N ''

# Add local group/user for Ansible and allow sudo NOPASSWD: ALL
id -u mansible &>/dev/null || useradd -u2001 -c "My Ansible" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' mansible
su - mansible -c "echo | ssh-keygen -trsa -b2048 -N ''"
cat << EOF > /etc/sudoers.d/01-myansble

# Allow the group 'mansible' to run sudo (ALL) with NOPASSWD
%mansible       ALL=(ALL)       NOPASSWD: ALL
EOF

# Setup wheel group for NOPASSWD: (only for a non-production ENV)
sed -i -e 's/^%wheel/#%wheel/g' /etc/sudoers
sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

yum -y install cockpit
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service=cockpit
firewall-cmd --complete-reload

#########################
## MONITORING AND SYSTEM MANAGEMENT
#########################
# Enable Cockpit (AFAIK this will be universally applied)
# Manage Cockpit

# Enable Repo for SNMP pkgs (might move this higher up in the script
case `cut -f5 -d\: /etc/system-release-cpe` in
  8.*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
    yum -y install  net-snmp-libs
  ;;
esac

# Setup the software RAID
parted -s /dev/sdb mklabel gpt mkpart pri xfs 2048s 100%
parted -s /dev/sdc mklabel gpt mkpart pri xfs 2048s 100%
mdadm --create --verbose /dev/md0 --level raid0 --raid-devices=2 /dev/sdb1 /dev/sdc1

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
# Configure Network Bridge
INTERFACE=eno1
cat << EOF > /root/nmcli_cmds.sh
nmcli con add type bridge autoconnect yes con-name brkvm ifname brkvm ip4 10.10.10.13/24 gw4 10.10.10.1
nmcli con modify brkvm ipv4.address 10.10.10.13/24 ipv4.method manual
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
## MONITORING AND SYSTEM MANAGEMENT
#
#####################################
#####################################
# Enable Cockpit (AFAIK this will be universally applied)
# Manage Cockpit
yum -y install cockpit
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service=cockpit
firewall-cmd --complete-reload

# Enable Repo for SNMP pkgs (might move this higher up in the script
case `cut -f5 -d\: /etc/system-release-cpe` in
  8.*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
    yum -y install  net-snmp-libs
  ;;
esac

# Enable SNMP (for LibreNMS)
yum -y install  net-snmp net-snmp-utils
mv /etc/snmp/snmpd.conf //etc/snmp/snmpd.conf-`date +%F`
curl http://${WEBSERVER}/Files/etc_snmp_snmpd.conf > /etc/snmp/snmpd.conf
restorecon -Fvv /etc/snmp/snmpd.conf
systemctl enable snmpd --now
firewall-cmd --permanent --add-service=snmp
firewall-cmd --reload

# Install Sysstat (SAR) and PCP
yum -y install sysstat pcp
systemctl enable sysstat --now

#  Update Host and reboot
echo "NOTE:  update and reboot"
yum -y update && shutdown now -r

exit 0




