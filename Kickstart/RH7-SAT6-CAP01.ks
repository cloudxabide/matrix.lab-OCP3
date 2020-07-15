#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline
# Use network installation
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=eth0 --gateway=10.10.10.1 --ip=10.10.10.103 --nameserver=8.8.8.8,8.8.4.4 --netmask=255.255.255.0 --noipv6 --activate --hostname=rh7-sat6-cap01.matrix.lab

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=morpheus --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="Morpheus"

# System timezone
timezone America/Chicago --isUtc --ntpservers=0.rhel.pool.ntp.org,1.rhel.pool.ntp.org,2.rhel.pool.ntp.org,3.rhel.pool.ntp.org

services --enabled=chronyd
selinux --enforcing

#########################################################################
### DISK ###
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
#ignoredisk --only-use=vda

# Partition clearing information
#autopart --type=lvm
clearpart --all --initlabel --drives=vda,vdb

# Partition Info
part /boot --fstype="xfs" --ondisk=vda --size=500
part pv.03 --fstype="lvmpv" --ondisk=vda --size=10240 --grow
#
volgroup vg_rhel7 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rhel7 --name=lv_root --label="root" --size=12288
logvol swap --fstype=swap --vgname=vg_rhel7 --name=lv_swap --label="swap" --size=5120
logvol /home --fstype=xfs --vgname=vg_rhel7 --name=lv_home --label="home" --size=1024 --fsoptions="nodev,nosuid"
logvol /tmp --fstype=xfs --vgname=vg_rhel7 --name=lv_tmp --label="temp" --size=1024 --fsoptions="nodev,nosuid"
logvol /var/tmp --fstype=xfs --vgname=vg_rhel7 --name=lv_vartmp --label="vartemp" --size=1024 --fsoptions="defaults,nodev,nosuid"
logvol /var/log --fstype=xfs --vgname=vg_rhel7 --name=lv_varlog --label="varlog" --size=1024 --fsoptions="defaults,nodev,nosuid,noexec"
logvol /var/spool --fstype=xfs --vgname=vg_rhel7 --name=lv_varspool --label="varspool" --size=8192 --fsoptions="defaults,nodev,nosuid,noexec"

# Satellite 6 Directories
part pv.04 --fstype="lvmpv" --ondisk=vdb --size=10240 --grow
volgroup vg_sat6 pv.04
logvol /var/lib/pulp --fstype=xfs --vgname=vg_sat6 --name=lv_pulp --label="pulp" --size=143360
logvol /var/cache/pulp --fstype=xfs --vgname=vg_sat6 --name=lv_cachepulp --label="cachepulp" --size=15360
logvol /var/lib/qpidd --fstype=xfs --vgname=vg_sat6 --name=lv_qpidd --label="qpidd" --size=1024
logvol /var/lib/mongodb --fstype=xfs --vgname=vg_sat6 --name=lv_mongodb --label="mongodb" --size=15360 
logvol /var/lib/pgsql --fstype=xfs --vgname=vg_sat6 --name=lv_pgsql --label="pgsql" --size=2048
logvol /var/www/html --fstype=xfs --vgname=vg_sat6 --name=lv_varwww --label="html" --size=2048

eula --agreed
reboot

%packages
@base
@core
yum-plugin-downloadonly
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/Scripts/post_install.sh -O /root/post_install.sh
%end
