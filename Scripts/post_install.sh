#!/bin/bash

#set -o errexit
readonly LOG_FILE="/root/post_install.sh.log"
echo "Output being redirected to log file - to see output:"
echo "tail -f $LOG_FILE"

# Simple test/check to see if script is still running, or has been run already
ps -ef | grep post_instaill.sh | grep -v grep && { echo "ERROR: script is already running"; exit 9; }
[ -f $LOG_FILE ] && { echo "Log File exists.  Remove log if you *really* want to run this script"; exit 9; }

touch $LOG_FILE
exec 1>$LOG_FILE 
exec 2>&1 
WEBSERVER="10.10.10.10"

PWD=`pwd`
DATE=`date +%Y%m%d`
ARCH=`uname -p`
YUM=$(which yum)

if [ `/bin/whoami` != "root" ]
then
  echo "ERROR:  You should be root to run this..."
  exit 9
fi

# Grab the finish_script (if available)
wget http://${WEBSERVER}/Scripts/finish_$(hostname -s | tr [a-z] [A-Z]).sh 

# Display warning (in case this script was run interactively)
SLEEPYTIME=5
echo "NOTE: This script will update host and REBOOT host"
echo "  Press CTRL-C to quit (you have ${SLEEPYTIME} seconds)"
while [ $SLEEPYTIME -gt 0 ]; do echo -ne "Will proceed in:  $SLEEPYTIME\033[0K\r"; sleep 1; : $((SLEEPYTIME--)); done

# Register the system if not already (exit if the config file is not present) - I need to get an activation key and use vault for this 
export rhnuser=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnuser | cut -f2 -d\=)
export rhnpass=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnpass | cut -f2 -d\=)
## OLD WAY - I don't like having the file sitting on the systems (getting stale, more easily obtained)
#[ ! -f ./rhninfo ] && { echo "grabbing RHN config"; wget ${WEBSERVER}/OS/.rhninfo || { echo "ERROR: could not retrieve RHN config"; exit 9;} }
#. ./.rhninfo || exit 9

subscription-manager status || subscription-manager register --auto-attach --force --username="${rhnuser}" --password="${rhnpass}"

# Repo/Channel Management
# subscription-manager facts --list  | grep distribution.version: | awk '{ print $2 }' <<== Alternate to gather "version"
case `cut -f5 -d\: /etc/system-release-cpe` in
  7.*)
    echo "NOTE:  detected EL7"
    subscription-manager repos --disable="*" --enable rhel-7-server-rpms
    subscription-manager release set=7.6
  ;;
  8.*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms  
  ;;
esac

# Install deltarpm to (hopefully) minimize the bandwith
yum -y install deltarpm

#########################
## USER MANAGEMENT
#########################
# Create an SSH key/pair if one does not exist (which should be the case for a new system)
[ ! -f /root/.ssh/id_rsa ] && echo | ssh-keygen -trsa -b2048 -N ''

# Add a local Docker group
groupadd docker 1001

# Add local group/user for Ansible and allow sudo NOPASSWD: ALL
id -u mansible &>/dev/null || useradd -u2001 -c "My Ansible" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' mansible 
su - mansible -c "echo | ssh-keygen -trsa -b2048 -N ''" 
cat << EOF > /etc/sudoers.d/01-myansble

# Allow the group 'mansible' to run sudo (ALL) with NOPASSWD
%mansible 	ALL=(ALL)	NOPASSWD: ALL
EOF

# Setup wheel group for NOPASSWD: (only for a non-production ENV)
sed -i -e 's/^%wheel/#%wheel/g' /etc/sudoers
sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

#########################
## MONITORING AND SYSTEM MANAGEMENT
#########################
# Enable Cockpit (AFAIK this will be universally applied)
# Manage Cockpit
yum -y install cockpit
systemctl enable cockpit.socket
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
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf-`date +%F`
WEBSERVER=10.10.10.10
curl http://${WEBSERVER}/Files/etc_snmp_snmpd.conf > /etc/snmp/snmpd.conf
restorecon -Fvv /etc/snmp/snmpd.conf
systemctl enable snmpd --now &
firewall-cmd --permanent --add-service=snmp
firewall-cmd --reload

# Install Sysstat (SAR) and PCP
yum -y install sysstat pcp
systemctl enable sysstat --now

#  Configure tuned
$(which yum) -y install tuned
case `dmidecode -s system-manufacturer` in
  'Red Hat'|'oVirt')
    tuned-adm profile virtual-guest
    subscription-manager repos --enable=rhel-7-server-rh-common-rpms
    yum -y install rhevm-guest-agent
    systemctl enable ovirt-guest-agent; systemctl start $_
  ;;
  HP)
    tuned-adm profile virtual-host
  ;;
  *)
    tuned-adm profile balanced
  ;;
esac 
 
#  Update Host and reboot
echo "NOTE:  update and reboot"
yum -y update && shutdown now -r

exit 0

## I believe the "deploy_cluster.yml" playbook takes care of this
## https://docs.openshift.com/container-platform/3.11/admin_guide/overcommit.html#disabling-swap-memory

