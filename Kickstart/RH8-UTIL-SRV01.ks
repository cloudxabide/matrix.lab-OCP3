#version=RHEL8
ignoredisk --only-use=vda
autopart --type=lvm
# Partition clearing information
clearpart --none --initlabel
# Use graphical install
graphical
repo --name="AppStream" --baseurl=file:///run/install/repo/AppStream
# Use CDROM installation media
cdrom
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=enp1s0 --gateway=10.10.10.1 --ip=10.10.10.100 --nameserver=10.10.10.121,10.10.10.122,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=rh8-util-srv01.matrix.lab
# Root password
rootpw --iscrypted $6$eUp.vIyPAe..7gIU$4H/7/MCo0MRTo1C5H/WVvcprjI2AT6TuiFGt/ixBG/k47aJWP9W7uSpu1hGZBDmNuSNYAdroSsoWB7WHzyfIV.
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --disabled="chronyd"
# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Production"
# System timezone
timezone America/Chicago --isUtc --nontp
user --groups=wheel --name=morpheus --password=$6$9FgTyBrUFwYH.oVq$bRuVjyR95xsn9jaY0oWfzSfqF1.J4bpHsktHeGi9E.ROXccaoJT5oK8a.zIrKdOtz.oQE0wTPvGSSlfAANAWL. --iscrypted --gecos="Morpheus"

%packages
@^server-product-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
