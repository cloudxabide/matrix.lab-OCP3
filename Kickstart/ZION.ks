#version=RHEL8
ignoredisk --only-use=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda
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
network  --bootproto=static --device=enp0s25 --gateway=10.10.10.1 --ip=10.10.10.10 --nameserver=10.10.10.121,10.10.10.122,8.8.8.8 --netmask=255.255.255.0 --onboot=off --ipv6=auto --no-activate
network  --hostname=zion.matrix.lab
# X Window System configuration information
xconfig  --startxonboot
# Run the Setup Agent on first boot
firstboot --enable
# System services
services --disabled="chronyd"
# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Development/Test"
# System timezone
timezone America/Chicago --isUtc --nontp

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=morpheus --password=$6$uMOD84f8rdYqFmOA$4eWu5kcXSqm4SDkBPHQcAkEjzD5Orwp8OjXSGYVQcyVGJOGeQ.ECclVrALxw4OL/kAZE7UmdE/yjRaJqKd/tb. --iscrypted --gecos="Morpheus"

# Disk partitioning information
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.492 --fstype="lvmpv" --ondisk=sda --size=75620
volgroup rhel --pesize=4096 pv.492
logvol / --fstype="xfs" --grow --size=1024 --name=root --vgname=rhel
logvol /var/log --fstype="xfs" --size=8192 --name=var_log --vgname=rhel
logvol swap --fstype="swap" --size=8025 --name=swap --vgname=rhel
logvol /var --fstype="xfs" --size=8192 --name=var --vgname=rhel

%packages
@^graphical-server-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
