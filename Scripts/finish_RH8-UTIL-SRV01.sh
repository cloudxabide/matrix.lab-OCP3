#!/bin/bash

PWD=`pwd`
DATE=`date +%Y%m%d`
ARCH=`uname -p`
YUM=$(which yum)

if [ `/bin/whoami` != "root" ]
then
  echo "ERROR:  You should be root to run this..."
  exit 9
fi

# Repo/Channel Management
# Typically you would not need to do this
subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms --enable=rhel-8-for-x86_64-supplementary-rpms --enable=rhel-8-for-x86_64-appstream-rpms
# Install EPEL (needed for Fail2Ban)
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Manage Security (local)
## Disable Passphrase Logins (keys only)
sed -i -e 's/^PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd

id -u jradtke &>/dev/null || useradd -u2025 -G10 -c "James Radtke" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' jradtke
chage -l jradtke

# Install/configure Fail2Ban
# Created a separate Installation file, as this will likely be used on several machines
./install_fail2ban.sh

# Install/configure AIDE

# Install/configure Apache/Php
yum -y install httpd php
systemctl enable httpd --now
firewall-cmd --permanent --add-service=httpd
firewall-cmd --reload
cat << EOF >  /var/www/html/index.html 
<HTML>
<HEAD>
<TITLE>You don't belong here | LinuxRevolution &#169</TITLE>
<META http-equiv="refresh" content="2;URL='https://www.youtube.com/watch?v=dQw4w9WgXcQ'">
<BODY>
You deserve this...
</BODY>
</HTML>
EOF
echo "Disallow: /*?*" > /var/www/html/robots.txt
restorecon -RFvv /var/www/html/
chmod 0644 /var/www/html/*


# Install/configure/manage Public Cert infrastructure (Let's Encrypt)
yum -y install certbot python2-certbot-apache


