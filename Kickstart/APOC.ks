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
network  --bootproto=dhcp --device=eno1 --ipv6=auto --activate
network  --bootproto=dhcp --device=ens6f0 --onboot=off --ipv6=auto
network  --bootproto=dhcp --device=ens6f1 --onboot=off --ipv6=auto
network  --hostname=apoc.matrix.private
# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
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
user --groups=wheel --name=morpheus --password=$6$llYOBfIhM3eVGk/R$N2ZjKNzJG/AZqZ4AOKNdoNo/oK.uI5ZPH9q18DSjFNeYoL8ekLicdVBd0J7VDBMgeOf5ZgqVVjukCQSYbYrph0 --iscrypted --gecos="Morpheus"
# Disk partitioning information
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.436 --fstype="lvmpv" --ondisk=sda --size=242573
part /boot --fstype="xfs" --ondisk=sda --size=1024
volgroup rhel_apoc --pesize=4096 pv.436
logvol /home --fstype="xfs" --grow --size=500 --name=home --vgname=rhel_apoc
logvol swap --fstype="swap" --size=24419 --name=swap --vgname=rhel_apoc
logvol / --fstype="xfs" --grow --size=1024 --name=root --vgname=rhel_apoc

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
