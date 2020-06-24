######### HOST SPECIFIC PARAMS - BEGIN  #########
# Network information
network --bootproto=static --device=bond0 --ip=10.10.10.11 --netmask=255.255.255.0 --gateway=10.10.10.1 --noipv6 --bondopts=miimon=100,mode=802.3ad,lacp_rate=1  --bondslaves=eno1,eno2 --hostname=neo.matrix.lab
network --bootproto=static --device=bond1 --ip=169.254.0.11 --bondopts=miimon=100,mode=802.3ad,lacp_rate=1  --bondslaves=ens3f0,ens3f1
network --bootproto=static --device=bond2 --ip=172.16.10.11 --netmask=255.255.255.0 --noipv6 --bondopts=miimon=100,mode=802.3ad,lacp_rate=1  --bondslaves=ens3f2,ens3f3
######### HOST SPECIFIC PARAMS - END #########

# Use text install
text
# Use network installation
#liveimg --url=http://10.10.10.10/OS/RHVH-4.3/LiveOS/squashfs.img
liveimg --url=http://10.10.10.10/OS/RHVH-4.3-SquashFS/redhat-virtualization-host-4.3.9-20200324.0.el7_8.squashfs.img

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8
# System authorization information
auth --enableshadow --passalgo=sha512

# SELinux configuration
selinux --enforcing
# System services
services --enabled="sshd" 
timezone America/Chicago --isUtc --ntpservers=0.rhel.pool.ntp.org,1.rhel.pool.ntp.org,2.rhel.pool.ntp.org
# Users 
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

# System bootloader configuration
bootloader --append=" crashkernel=auto hpsa.hpsa_allow_any=1 hpsa.hpsa_simple_mode=1 console=tty0 console=ttyS0,9600n8" --location=mbr --timeout=1 --boot-drive=sda

###############################################################################
# Disk Management
# Pre-script to wipe disks
%pre --log=/tmp/ks_pre_diskman.log
#!/bin/sh
for DEV in b c d
do
if [ -b /dev/sd${DEV} ]
then
  dd if=/dev/zero of=/dev/sd${DEV} bs=512 count=20480
  wipefs --all --force /dev/sd${DEV}
  partprobe /dev/sd${DEV}
fi
done
%end

zerombr
clearpart --all --initlabel --drives=sda
ignoredisk --only-use=sda
#autopart --type=thinp
# https://access.redhat.com/documentation/en-us/red_hat_virtualization/4.3/html/installation_guide/advanced_rhvh_install
part /boot/efi --fstype="efi"   --size=256   --ondisk=sda --fsoptions="umask=0077,shortname=winnt" 
part /boot     --fstype="xfs"   --size=1024  --ondisk=sda 
part pv.01     --fstype="lvmpv" --size=51200 --ondisk=sda --grow
# 
volgroup rhvh_neo --pesize=4096 pv.01 --reserved-percent=20
# 
logvol none           --thinpool      --size=51200  --grow                     --vgname=rhvh_neo --name=HostPool 
# 
logvol swap           --fstype="swap" --recommended                            --vgname=rhvh_neo --name=swap                 
logvol /              --fstype="xfs"  --size=10240  --thin --poolname=HostPool --vgname=rhvh_neo --name=root          --fsoptions="defaults,discard" 
logvol /tmp           --fstype="xfs"  --size=1024   --thin --poolname=HostPool --vgname=rhvh_neo --name=tmp           --fsoptions="defaults,discard"  
logvol /var           --fstype="xfs"  --size=10240  --thin --poolname=HostPool --vgname=rhvh_neo --name=var           --fsoptions="defaults,discard" 
logvol /home          --fstype="xfs"  --size=1024   --thin --poolname=HostPool --vgname=rhvh_neo --name=home          --fsoptions="defaults,discard" 
logvol /var/crash     --fstype="xfs"  --size=10240  --thin --poolname=HostPool --vgname=rhvh_neo --name=var_crash     --fsoptions="defaults,discard"
logvol /var/log       --fstype="xfs"  --size=8192   --thin --poolname=HostPool --vgname=rhvh_neo --name=var_log       --fsoptions="defaults,discard" 
logvol /var/log/audit --fstype="xfs"  --size=2048   --thin --poolname=HostPool --vgname=rhvh_neo --name=var_log_audit --fsoptions="defaults,discard" 

###############################################################################
# reboot after installation
reboot

%post --erroronfail --log=/root/ks-post.log
nodectl init
echo | ssh-keygen -trsa -b2048 -N ''
curl -o /root/post_install.sh http://10.10.10.10/post_install.sh
%end

%addon com_redhat_kdump --enable --reserve-mb='auto' 
%end
