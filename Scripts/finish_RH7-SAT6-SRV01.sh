#!/bin/bash

# System Vars
cat << EOF > ~/satellite_info.txt
ORGANIZATION="MATRIXLABS"
LOCATION="HomeLab"
SATELLITE="rh7-sat6-srv01"
DOMAIN="matrix.lab"
SATVERSION=6.5
EOF
. ~/satellite_info.txt

# Manage Subscription and Channels/Repos
# This *would* likely be necessary for a "normal" RHN account
# POOL=`subscription-manager list --available --matches 'Red Hat Satellite' | grep "Pool ID:" | awk '{ print $3 }' | tail -1`
# subscription-manager attach --pool=${POOL}

case $SATVERSION in
  6.5)
    subscription-manager repos --enable=rhel-7-server-rpms \
      --enable=rhel-server-rhscl-7-rpms \
      --enable=rhel-7-server-satellite-6.5-rpms \
      --enable=rhel-7-server-satellite-maintenance-6-rpms \
      --enable=rhel-7-server-ansible-2.6-rpms
  ;;
  6.2)
    echo ""
  ;;
esac
subscription-manager release --unset

# Update Firewall
TCP_PORTS="53 80 443 5000 5646 5647 5671 8000 8140 9090"
UDP_PORTS="53 67 68 69"
NETWORK_SERVICES="RH-Satellite-6"
for PORT in $TCP_PORTS
do
  firewall-cmd --permanent --add-port=$PORT/tcp
done
for PORT in $UDP_PORTS
do
  firewall-cmd --permanent --add-port=$PORT/udp
done
for SERVICE in $NETWORK_SERVICES 
do
  firewall-cmd --permanent --add-service=$SERVICE
done
firewall-cmd --reload

# Install Satellite
yum -y install satellite

yum -y install chrony
systemctl enable --now chronyd

yum -y install sos

# Default Answers (Params) File
# /etc/foreman-installer/scenarios.d/satellite-answers.yaml
# /etc/foreman-installer/scenarios.d/satellite.yaml
#  satellite-installer --scenario satellite --help

# Copy the default answers file for modification
cp /etc/foreman-installer/scenarios.d/satellite-answers.yaml /etc/foreman-installer/scenarios.d/${ORGANIZATION}-satellite-answers.yaml
# Update the install file for your custom Answers file
sed -i -e "s/satellite-answers/${ORGANIZATION}-satellite-answers/g" /etc/foreman-installer/scenarios.d/satellite.yaml

# Save the manifest file in ~ - then upload it
hammer subscription upload --file $(find ~ -name "*$MATRIXLABS*.zip") --organization="${ORGANIZATION}" 


###################
# --source-id=1 (should be INTERNAL)
hammer user create --login satadmin --mail="satadmin@${SATELLITE}.${DOMAIN}" --firstname="Satellite" --lastname="Adminstrator" --password="Passw0rd" --auth-source-id=1
hammer user add-role --login=satadmin --role-id=9
hammer user create --login reguser --mail="reguser@${SATELLITE}.${DOMAIN}" --firstname="Registration" --lastname="User" --password="Passw0rd" --auth-source-id=1
hammer user-group create --name="regusers" --role-ids=12 --users=satadmin,reguser

#hammer organization create --name="${ORGANIZATION}" --label="${ORGANIZATION}"
hammer organization add-user --user=satadmin --name="${ORGANIZATION}"
hammer organization add-user --user=reguser --name="${ORGANIZATION}"

hammer location create --name="${LOCATION}"
hammer location add-organization --name="${LOCATION}" --organization="${ORGANIZATION}"
hammer domain create --name="${DOMAIN}"
hammer subnet create --domain-ids=1 --gateway='10.10.10.1' --mask='255.255.255.0' --name='10.10.10.0/24' --network='10.10.10.0' --dns-primary='10.10.10.121' --dns-secondary='10.10.10.122'
hammer organization add-subnet --subnet-id=1 --name="${ORGANIZATION}"
hammer organization add-domain --domain="${DOMAIN}" --name="${ORGANIZATION}"

######################
## Collect information
hammer product list --organization="${ORGANIZATION}" > ~/hammer_product_list.out

######################
PRODUCT='Red Hat Enterprise Linux Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
#REPOS="3815 2463 2472 2456 2476"
REPOS="2472 2456"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='7Server' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='7.7' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7.7' --product="${PRODUCT}" --id="${REPO}"
done
## THERE ARE REPOS WHICH DO *NOT* ACCEPT A "releasever" VALUE
REPOS="8503" # Satellite Tools 6.5
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat Software Collections for RHEL Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="2808"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat Ansible Engine'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="7387"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat OpenShift Container Platform'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
#REPOS="5251"  # 3.3
REPOS="7414 6888"  # 3.11 3.9
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

#################
## EPEL Stuff - Pay attention to the output of this section.  It's not tested/validated
#    If it doesn't work, update the GPG-KEY via the WebUI
wget -q https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7  -O /root/RPM-GPG-KEY-EPEL-7
hammer gpg create --key /root/RPM-GPG-KEY-EPEL-7 --name 'GPG-EPEL-7' --organization="${ORGANIZATION}"
GPGKEYID=`hammer gpg list --name="GPG-EPEL-7" --organization="${ORGANIZATION}" | grep ^[0-9] | awk '{ print $1 }'`
PRODUCT='Extra Packages for Enterprise Linux'
hammer product create --name="${PRODUCT}" --organization="${ORGANIZATION}"
hammer repository create --name='EPEL 7 - x86_64' --organization="${ORGANIZATION}" --product="${PRODUCT}" --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/ --gpg-key-id="${GPGKEYID}" --gpg-key="${GPG-EPEL-7}"

#################
## SYNC EVERYTHING (Manually)
for i in $(hammer --csv repository list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do hammer repository synchronize --id ${i} --organization="${ORGANIZATION}" --async; sleep 1; done

################
# SYNC PLANS - I believe these are working now.
#   I may... want to separate all the major products out to their own Sync Plan though.
hammer sync-plan create --enabled true --interval=daily --name='Daily sync - Red Hat' --description="Daily Sync Plan for Red Hat Products" --sync-date='2015-11-22 02:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Ansible Engine'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Linux Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat OpenShift Container Platform'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Software Collections for RHEL Server'
hammer sync-plan create --enabled true --interval=daily --name='Daily sync - EPEL' --description="Daily Sync Plan for EPEL" --sync-date='2015-11-22 03:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - EPEL' --organization="${ORGANIZATION}" --name='Extra Packages for Enterprise Linux'

#################
## LIFECYCLE ENVIRONMENT
hammer lifecycle-environment create --name='DEV' --prior='Library' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='TEST' --prior='DEV' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='PROD' --prior='TEST' --organization="${ORGANIZATION}"
