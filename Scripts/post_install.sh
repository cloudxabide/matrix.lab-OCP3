#!/bin/bash

set -o errexit
readonly LOG_FILE="/root/post_install.sh.log"
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

wget http://${WEBSERVER}/Scripts/finish_$(hostname -s | tr [a-z] [A-Z]).sh 

# Display warning (in case this is run interactively
echo "NOTE: This script will update host and REBOOT host"
echo "  Press CTRL-C to quit (you have 5 seconds)"
sleep 5

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
  ;;
  8.*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms 
  ;;
esac

#########################
## USER MANAGEMENT
#########################
# Create an SSH key/pair if one does not exist (which should be the case for a new system)
[ ! -f /root/.ssh/id_rsa ] && echo | ssh-keygen -trsa -b2048 -N ''

# Add local group/user for Ansible and allow sudo NOPASSWD: ALL
id -u mansible &>/dev/null || useradd -u1001 -c "My Ansible" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' mansible 
su - mansible -c "echo | ssh-keygen -trsa -b2048 -N ''"

cat << EOF > /etc/sudoers.d/01-myansble

# Allow the group 'mansible' to run sudo (ALL) with NOPASSWD
%mansible 	ALL=(ALL)	NOPASSWD: ALL
EOF

# Setup wheel group for NOPASSWD: (only for a non-production ENV)
sed -i -e 's/^%wheel/#%wheel/g' /etc/sudoers
sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

# Enable Cockpit (AFAIK this will be universally applied)
# Manage Cockpit
yum -y install cockpit
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service=cockpit 
firewall-cmd --complete-reload

#  Update Host and reboot
yum -y update && shutdown now -r
