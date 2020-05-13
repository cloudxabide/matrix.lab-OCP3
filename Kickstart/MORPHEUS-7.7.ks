#version=DEVEL
#
#  NOTE : NOTE : This kickstart profile is setup for 7.5 and to comply as a RHV-Hypervisor
#  NOTE:         Also - this profile includes HP-specific boot params
#
# System authorization information
auth --enableshadow --passalgo=sha512
url --url="http://10.10.10.10/OS/rhel-server-7.7-x86_64/"
cmdline
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=eno1 --onboot=on --ipv6=auto --activate --ip=10.10.10.13 --netmask=255.255.255.0 --gateway=10.10.10.1 --nameserver=10.10.10.121,10.10.10.122,8.8.8.8                     
network  --bootproto=static --device=eno2 --onboot=off --ipv6=auto --no-activate
network  --bootproto=static --device=ens3f0 --onboot=off --ipv6=auto --no-activate
network  --bootproto=static --device=ens3f1 --onboot=off --ipv6=auto --no-activate
network  --bootproto=static --device=ens3f2 --onboot=off --ipv6=auto --activate --ip=172.16.10.13 --netmask=255.255.255.0
network  --bootproto=static --device=ens3f3 --onboot=off --ipv6=auto --no-activate
network  --hostname=morpheus.matrix.lab

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

# System services
services --enabled="chronyd cockpit"
firewall --enabled --service=ntpd --service=sshd --service=cockpit --port=9090:tcp

# System timezone
timezone America/Chicago --isUtc --ntpservers=2.rhel.pool.ntp.org,3.rhel.pool.ntp.org,1.rhel.pool.ntp.org
# System bootloader configuration
bootloader --location=mbr --boot-drive=sda --append=" crashkernel=auto hpsa.hpsa_allow_any=1 hpsa.hpsa_simple_mode=1 console=tty0 console=ttyS0,9600n8"

# Partition clearing information
#ignoredisk --only-use=sda
zerombr
clearpart --all --initlabel --drives=sda,sdb,sdc

# Disk partitioning information
part /boot/efi --fstype="efi" --fsoptions="umask=0077,shortname=winnt" --ondisk=sda --size=256
part /boot --fstype="xfs" --ondisk=sda --size=1024
part pv.01 --fstype="lvmpv" --ondisk=sda --size=51200 --grow
volgroup vg_rhel7 --pesize=4096 pv.01
logvol /              --fstype="xfs"  --size=10240 --name=root     --vgname=vg_rhel7
logvol /home          --fstype="xfs"  --size=1024  --name=home     --vgname=vg_rhel7
logvol /tmp           --fstype="xfs"  --size=1024  --name=tmp      --vgname=vg_rhel7
logvol /var           --fstype="xfs"  --size=15360 --name=var      --vgname=vg_rhel7
logvol /var/log       --fstype="xfs"  --size=8192  --name=varlog   --vgname=vg_rhel7
logvol /var/log/audit --fstype="xfs"  --size=2048  --name=varaudit --vgname=vg_rhel7
logvol swap           --fstype="swap" --size=4096  --name=swap     --vgname=vg_rhel7

# RAID-0 the 2 "extra" disks (sdb, sdc)
part raid.0011 --size 200 --asprimary --grow --ondrive=sdb
part raid.0021 --size 200 --asprimary --grow --ondrive=sdc
raid pv.0001 --fstype xfs --device md0 --level=RAID0 raid.0011 raid.0021
volgroup vg_data --pesize=4096 pv.0001
logvol /data --vgname=vg_data --size=3000 --name=data --grow

reboot
eula --agreed

%packages
@^minimal
@core
@virtualization-hypervisor
@virtualization-client
@virtualization-platform
@virtualization-tools
cockpit
chrony
kexec-tools
wget 
deltarpm
net-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%post --log=/root/ks-post.log
echo "NOTE:  Retrieving Finish Script"
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh

# Create mount for Guest VMs
mkdir /data/images # do not use -p, I WANT this to fail if /data is not there
mkdir -p /var/lib/libvirt/images/
echo "# BIND mount for Guest VMs" >> /etc/fstab
echo "/data/images /var/lib/libvirt/images/ none bind,defaults 0 0" >> /etc/fstab

%end

%anaconda
pwpolicy root --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy luks --minlen=6 --minquality=50 --notstrict --nochanges --notempty
%end

