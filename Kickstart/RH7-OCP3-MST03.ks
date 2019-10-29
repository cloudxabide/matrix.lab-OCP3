#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline
# Use network installation
url --url="http://10.10.10.10/OS/rhel-server-7.6-x86_64/"
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=eth0 --ip=10.10.10.173 --netmask=255.255.255.0 --gateway=10.10.10.1 --activate --nameserver=10.10.10.121,10.10.10.122,8.8.8.8 --hostname=rh7-ocp3-mst03.matrix.lab 

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=morpheus --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="Morpheus"

# System timezone
timezone America/Chicago --isUtc --ntpservers=rh7-idm-srv01.matrix.lab,rh7-idm-srv02.matrix.lab,rh7-sat6-srv01.matrix.lab

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
volgroup vg_rhel75 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rhel75 --name=lv_root --label="root" --size=8192
logvol swap --fstype=swap --vgname=vg_rhel75 --name=lv_swap --label="swap" --size=2048
logvol /home --fstype=xfs --vgname=vg_rhel75 --name=lv_home --label="home" --size=1024
logvol /tmp --fstype=xfs --vgname=vg_rhel75 --name=lv_tmp --label="temp" --size=2048
logvol /var/lib/openshift --fstype=xfs --vgname=vg_rhel75 --name=lv_openshift  --label="openshift" --size=1024

eula --agreed
reboot

%packages
@base
@core
git
ntp
perl
tuned
wget
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
echo -e "# BIND Mount CCE-14584-7"
echo -e "/tmp\t\t/var/tmp\t\t\tnone\tdefaults,bind,nodev,noexec,nosuid\t0 0" >> /etc/fstab
# CCE-14054-1 
echo "NOZEROCONF=yes" >> /etc/sysconfig/network



%end

