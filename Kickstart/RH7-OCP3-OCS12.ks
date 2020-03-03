#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline
# Use network installation
url --url="http://10.10.10.10/OS/rhel-server-7.7-x86_64/"
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=eth0 --ip=10.10.10.197 --netmask=255.255.255.0 --gateway=10.10.10.1 --activate --nameserver=10.10.10.121,10.10.10.122 --hostname=rh7-ocp3-ocs12.matrix.lab 

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=morpheus --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="Morpheus"

# System timezone
timezone America/Chicago --isUtc --ntpservers=0.rhel.pool.ntp.org,1.rhel.pool.ntp.org,2.rhel.pool.ntp.org,3.rhel.pool.ntp.org

#########################################################################
### DISK ###
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
ignoredisk --only-use=vda

# Partition clearing information
clearpart --all --initlabel --drives=vda

# Partition Info
part /boot --fstype="xfs" --ondisk=vda --size=500
part pv.03 --fstype="lvmpv" --ondisk=vda --size=10240 --grow
#
volgroup vg_rhel7 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rhel7 --name=lv_root --label="root" --size=10240
logvol /home --fstype=xfs --vgname=vg_rhel7 --name=lv_home --label="home" --size=1024
logvol /tmp --fstype=xfs --vgname=vg_rhel7 --name=lv_tmp --label="temp" --size=2048
logvol /var --fstype=xfs --vgname=vg_rhel7 --name=lv_var --label="var" --size=8192
logvol /var/lib/openshift --fstype=xfs --vgname=vg_rhel7 --name=lv_openshift  --label="openshift" --size=1024

eula --agreed
reboot

%packages
@base
@core
ntp
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/Scripts/post_install.sh -O /root/post_install.sh
%end

