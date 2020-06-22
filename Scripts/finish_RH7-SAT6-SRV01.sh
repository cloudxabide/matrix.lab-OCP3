#!/bin/bash

# System Vars
cat << EOF > ~/satellite_info.txt
ORGANIZATION="MATRIXLABS"
LOCATION="HomeLab"
SATELLITE="rh7-sat6-srv01"
DOMAIN="matrix.lab"
SATVERSION=6.6
EOF
. ~/satellite_info.txt

cat << EOF > ~/.bashrc

if [ -f ${HOME}/satellite_info.txt ]; then
  . ${HOME}/satellite_info.txt
fi
EOF

# Manage Subscription and Channels/Repos
# This *would* likely be necessary for a "normal" RHN account
POOL=`subscription-manager list --available --matches 'Red Hat Satellite' | grep "Pool ID:" | awk '{ print $3 }' | tail -1`
subscription-manager attach --pool=${POOL}

subscription-manager repos --disable="*"
case $SATVERSION in
  6.6)
    subscription-manager repos --enable=rhel-7-server-rpms \
      --enable=rhel-7-server-satellite-6.6-rpms \
      --enable=rhel-7-server-satellite-maintenance-6-rpms \
      --enable=rhel-server-rhscl-7-rpms \
      --enable=rhel-7-server-ansible-2.8-rpms
  ;;
  6.5)
    subscription-manager repos --enable=rhel-7-server-rpms \
      --enable=rhel-server-rhscl-7-rpms \
      --enable=rhel-7-server-satellite-6.5-rpms \
      --enable=rhel-7-server-satellite-maintenance-6-rpms \
      --enable=rhel-7-server-ansible-2.6-rpms
  ;;
  6.2)
    echo "Seriously?  LIke.. Seriously?  Upgrade"
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

satellite-installer --scenario satellite \
--foreman-initial-organization "$ORGANIZATION" \
--foreman-initial-location "$LOCATION" \
--foreman-initial-admin-username "admin" \
--foreman-initial-admin-password "Passw0rd" \
--foreman-proxy-puppetca true \
--foreman-proxy-tftp true \
--enable-foreman-plugin-discovery \
--foreman-proxy-dns true \
--foreman-proxy-dns-interface eth0 \
--foreman-proxy-dns-zone matrix.lab \
--foreman-proxy-dns-forwarders 10.10.10.121 \
--foreman-proxy-dns-forwarders 10.10.10.122 \
--foreman-proxy-dns-reverse 10.10.10.in-addr.arpa \
--foreman-proxy-dhcp true \
--foreman-proxy-dhcp-interface eth0 \
--foreman-proxy-dhcp-range "10.10.10.200 10.10.10.250" \
--foreman-proxy-dhcp-gateway 10.10.10.1 \
--foreman-proxy-dhcp-nameservers 10.10.10.121 \
--foreman-proxy-dhcp-nameservers 10.10.10.122 \
--foreman-proxy-tftp true \
--foreman-proxy-tftp-servername ${SATELLITE}.${DOMAIN}
}

# Save the manifest file in ~ - then upload it
hammer subscription upload --file $(find ~ -name "*$MATRIXLABS*.zip") --organization="${ORGANIZATION}" 

# If you run yum update, you may also need to 
# https://access.redhat.com/solutions/4796841
# satellite-installer --scenario satellite --upgrade

###################
# --source-id=1 (should be INTERNAL)
hammer user create --login satadmin --mail="satadmin@${SATELLITE}.${DOMAIN}" --firstname="Satellite" --lastname="Adminstrator" --password="Passw0rd" --auth-source-id=1
hammer user add-role --login=satadmin --role-id=9
hammer user create --login reguser --mail="reguser@${SATELLITE}.${DOMAIN}" --firstname="Registration" --lastname="User" --password="Passw0rd" --auth-source-id=1
hammer user-group create --name="regusers" --role-ids=12 --users=satadmin,reguser

hammer organization create --name="${ORGANIZATION}" --label="${ORGANIZATION}"
hammer organization add-user --user=satadmin --name="${ORGANIZATION}"
hammer organization add-user --user=reguser --name="${ORGANIZATION}"

hammer location create --name="${LOCATION}"
hammer location add-organization --name="${LOCATION}" --organization="${ORGANIZATION}"
hammer domain create --name="${DOMAIN}"
hammer subnet create --name='10.10.10.0/24' \
  --description "Default Subnet for $ORGANIZATION" --organization "$ORGANIZATION" \
  --network='10.10.10.0' --boot-mode="DHCP" \
  --domains "$DOMAIN"  --gateway='10.10.10.1' --mask='255.255.255.0' \
  --dns-primary='10.10.10.121' --dns-secondary='10.10.10.122' 
hammer organization add-subnet --subnet-id=1 --name="${ORGANIZATION}"
hammer organization add-domain --domain="${DOMAIN}" --name="${ORGANIZATION}"

######################
## Collect information
hammer product list --organization="${ORGANIZATION}" > ~/hammer_product_list.out

######################
# RHEL 8 (Work In Progress)
PRODUCT='Red Hat Enterprise Linux for x86_64'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="7416 7441 7421"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='8' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='8' --product="${PRODUCT}" --id="${REPO}"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='8.1' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='8.1' --product="${PRODUCT}" --id="${REPO}"
done

REPOS="8693 8979" # Satellite Tools 6.5/6.6 for RHEL 8 
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

######################
# RHEL 6/7
PRODUCT='Red Hat Enterprise Linux Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="3030"
for REPO in $REPOS
do
  for RELEASEVER in 7Server
  do
    echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
    echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever=$RELEASEVER --product=\"${PRODUCT}\" --id=\"${REPO}\" "
    hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever=$RELEASEVER --product="${PRODUCT}" --id="${REPO}"
  done
done

REPOS="2456 2472 2455"
for REPO in $REPOS
do
  for RELEASEVER in 7.7 7.8
  do
    echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
    echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever=$RELEASEVER --product=\"${PRODUCT}\" --id=\"${REPO}\" "
    hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever=$RELEASEVER --product="${PRODUCT}" --id="${REPO}"
  done
done

## THERE ARE REPOS WHICH DO *NOT* ACCEPT A "releasever" VALUE
REPOS="8503 8935" # Satellite Tools 6.5/6.6
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
REPOS="7387 8562 9318"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat OpenShift Container Platform'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
#REPOS="5251"  # 3.3
REPOS="7414" # 3.11 3.9 - 6888 
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat Virtualization Host'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="5167"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

PRODUCT='Red Hat Virtualization Manager'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="7683"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done

PRODUCT='Red Hat Gluster Storage Server for On-premise'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="4604 4406"
for RELEASEVER in 7Server
do
  for REPO in $REPOS
  do
    echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
    echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever=$RELEASEVER --product=\"${PRODUCT}\" --id=\"${REPO}\" "
    hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever=$RELEASEVER --product="${PRODUCT}" --id="${REPO}"
  donek 
done

REPOS="2981"
for RELEASEVER in 7.7 7.8
do
  for REPO in $REPOS
  do
    echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
    echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever=$RELEASEVER --product=\"${PRODUCT}\" --id=\"${REPO}\" "
    hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever=$RELEASEVER --product="${PRODUCT}" --id="${REPO}"
  done
done 

#################
## EPEL Stuff - Pay attention to the output of this section.  It's not tested/validated
#    If it doesn't work, update the GPG-KEY via the WebUI
wget -q https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7  -O /root/RPM-GPG-KEY-EPEL-7
hammer gpg create --key /root/RPM-GPG-KEY-EPEL-7 --name 'GPG-EPEL-7' --organization="${ORGANIZATION}"
GPGKEYID=`hammer gpg list --name="GPG-EPEL-7" --organization="${ORGANIZATION}" | grep ^[0-9] | awk '{ print $1 }'`
PRODUCT='Extra Packages for Enterprise Linux 7'
hammer product create --name="${PRODUCT}" --organization="${ORGANIZATION}"
hammer repository create --name='EPEL 7 - x86_64' --organization="${ORGANIZATION}" --product="${PRODUCT}" --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/ --gpg-key-id="${GPGKEYID}" --gpg-key="${GPG-EPEL-7}"

wget -q https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8  -O /root/RPM-GPG-KEY-EPEL-8
hammer gpg create --key /root/RPM-GPG-KEY-EPEL-8 --name 'GPG-EPEL-8' --organization="${ORGANIZATION}"
GPGKEYID=`hammer gpg list --name="GPG-EPEL-8" --organization="${ORGANIZATION}" | grep ^[0-9] | awk '{ print $1 }'`
PRODUCT='Extra Packages for Enterprise Linux 8'
hammer product create --name="${PRODUCT}" --organization="${ORGANIZATION}"
hammer repository create --name='EPEL 8 - x86_64' --organization="${ORGANIZATION}" --product="${PRODUCT}" --content-type='yum' --publish-via-http=true --url=https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/ --gpg-key-id="${GPGKEYID}" --gpg-key="${GPG-EPEL-8}"

#################
## SYNC EVERYTHING (Manually)
for i in $(hammer --csv repository list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do hammer repository synchronize --id ${i} --organization="${ORGANIZATION}" --async; sleep 1; done

################
# SYNC PLANS - I believe these are working now.
#   I may... want to separate all the major products out to their own Sync Plan though.
hammer sync-plan create --enabled true --interval=daily --name='Daily sync - Red Hat' --description="Daily Sync Plan for Red Hat Products" --sync-date='2015-11-22 02:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Ansible Engine'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Linux Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Linux for x86_64'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat OpenShift Container Platform'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Software Collections for RHEL Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Virtualization Host'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Virtualization Manager'

hammer sync-plan create --enabled true --interval=daily --name='Daily sync - EPEL' --description="Daily Sync Plan for EPEL" --sync-date='2015-11-22 03:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - EPEL' --organization="${ORGANIZATION}" --name='Extra Packages for Enterprise Linux'
hammer product set-sync-plan --sync-plan='Daily sync - EPEL' --organization="${ORGANIZATION}" --name='Extra Packages for Enterprise Linux 8'

#################
## LIFECYCLE ENVIRONMENT
hammer lifecycle-environment create --name='DEV' --prior='Library' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='TEST' --prior='DEV' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='PROD' --prior='TEST' --organization="${ORGANIZATION}"

#################
## Create Activation Keys
hammer activation-key create --name "ak-ocp3" --unlimited-hosts --description "AK for OCP3" \
  --lifecycle-environment "Library"  --organization="${ORGANIZATION}"
SUBID=$(hammer subscription list --organization="${ORGANIZATION}" --search "OpenShift Employee Subscription" | egrep -v '^ID|^-' | awk -F\| '{ print $2 }' | sed 's/ //g')
hammer activation-key add-subscription --name "ak-ocp3" --subscription-id "${SUBID}" --organization "MATRIXLABS"
hammer activation-key content-override --name "ak-ocp3" --content-label rhel-7-server-satellite-tools-6.6-rpms  --value 1 --organization "${ORGANIZATION}"

hammer activation-key create --name "ak-rhel7-library-infra" --unlimited-hosts --description "RHEL 7 (Library) for Infra" \
  --lifecycle-environment "Library"  --organization="${ORGANIZATION}"
SUBID=$(hammer subscription list --organization="${ORGANIZATION}" --search "Employee SKU" | egrep -v '^ID|^-' | awk -F\| '{ print $2 }' | sed 's/ //g')
hammer activation-key add-subscription --name "ak-rhel7-library-infra" --subscription-id "${SUBID}" --organization "MATRIXLABS"
hammer activation-key content-override --name "ak-rhel7-library-infra" --content-label rhel-7-server-satellite-tools-6.6-rpms  --value 1 --organization "${ORGANIZATION}"

hammer activation-key create --name "ak-rhel8-library-infra" --unlimited-hosts --description "RHEL 8 (Library) for Infra" \
  --lifecycle-environment "Library"  --organization="${ORGANIZATION}"
SUBID=$(hammer subscription list --organization="${ORGANIZATION}" --search "Employee SKU" | egrep -v '^ID|^-' | awk -F\| '{ print $2 }' | sed 's/ //g')
hammer activation-key add-subscription --name "ak-rhel8-library-infra" --subscription-id "${SUBID}" --organization "MATRIXLABS"
hammer activation-key content-override --name "ak-rhel8-library-infra" --content-label rhel-8-server-satellite-tools-6.6-rpms  --value 1 --organization "${ORGANIZATION}"

# POC Activation Keys
# TODO: parameterize the OS version too
OSREL="rhel-7"
ENV="poc"
for LCE in DEV TEST PROD
do
  hammer activation-key create --name "ak-${ENV}-${LCE}-${OSREL}" --unlimited-hosts \
    --description "${OSREL} (${LCE}) for ${ENV}" \
    --lifecycle-environment "${LCE}"  --organization="${ORGANIZATION}" \ 
    SUBID=$(hammer subscription list --organization="${ORGANIZATION}" --search "Employee SKU" | egrep -v '^ID|^-' | awk -F\| '{ print $2 }' | sed 's/ //g')
  hammer activation-key add-subscription --name "ak-${ENV}-${LCE}-${OSREL}" --subscription-id "${SUBID}" \
    --organization "${ORGANIZATION}"
  hammer activation-key content-override --name "ak-${ENV}-${LCE}-${OSREL}" \
    --content-label ${OSREL}-server-satellite-tools-${SATVERSION}-rpms \
    --value 1 --organization "${ORGANIZATION}"
done

#  Create SCAP Content
# https://access.redhat.com/documentation/en-us/red_hat_satellite/6.7/html/administering_red_hat_satellite/chap-red_hat_satellite-administering_red_hat_satellite-security_compliance_management
foreman-rake foreman_openscap:bulk_upload:default
hammer scap-content create --title "ssg-rhel7-ds" \
  --location "$LOCATION" --organization "$ORGANIZATION" \
  --scap-file "/usr/share/xml/scap/ssg/content/ssg-rhel7-ds.xml" 
  
# Create a hostgroup
hammer hostgroup create --name "HostGroup-apoc-POC-Dev" \
  --organization "$ORGANIZATION" --location "$LOCATION" \
  --architecture "x86_64" --lifecycle-environment "POC-Dev"

# POC KVM-based Provisioning (optional - mostly here as a reference)
# https://access.redhat.com/documentation/en-us/red_hat_satellite/6.7/html/provisioning_guide/provisioning_virtual_machines_in_kvm
HYPERVISORS="neo trinity morpheus apoc cypher"
for HYPERVISOR in $HYPERVISORS 
do 
  hammer compute-resource create --name "$HYPERVISOR - KVM Server" \
--provider "Libvirt" --description "KVM server at $HYPERVISOR.matrix.lab" \
--url "qemu+ssh://root@$HYPERVISOR.matrix.lab/system" --locations "$LOCATION" \
--organizations "$ORGANIZATION"
done

# Might add this to the for-loop above
hammer compute-resource image create --name "Test KVM Image" \
--operatingsystem "RedHat 7.8" --architecture "x86_64" --username root \
--user-data false --uuid "/var/lib/libvirt/images/TestImage.qcow2" \
--compute-resource "apoc - KVM Server"

# Create a Compute Profile (CP) then update it
hammer compute-profile create --name "Libvirt CP"
# This is where things really matter
hammer compute-profile values create --compute-profile "Libvirt CP" \
--compute-resource "apoc - KVM Server" \
--interface "compute_type=network,compute_model=virtio,compute_network=brkvm" \
--volume "pool_name=default,capacity=40G,format_type=qcow2" \
--compute-attributes "cpus=2,memory=1536000000"

# Build a KVM Guest (I prefer the build image method)
hammer host create --name "kvm-test1" --organization "$ORGANIZATION" \
--location "$LOCATION" --hostgroup "Base" \
--compute-resource "apoc - KVM Server" --provision-method build \
--build true --enabled true --managed true \
--interface "managed=true,primary=true,provision=true,compute_type=network,compute_network=brkvm" \
--compute-attributes="cpus=2,memory=1536000000" \
--volume="pool_name=default,capacity=40G,format_type=qcow2" \
--root-password "Passw0rd"
