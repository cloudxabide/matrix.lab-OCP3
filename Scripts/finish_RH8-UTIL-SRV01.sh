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
dnf -y install fail2ban
cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local

cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 192.168.0.0/24
bantime  = 21600
findtime  = 300
maxretry = 3
banaction = iptables-multiport
backend = systemd

[sshd]
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
enabled = true
EOF

systemctl enable --now fail2ban


# Install/configure AIDE

# Install/configure Apache/Php
yum -y install httpd php
systemctl enable httpd --now
firewall-cmd --permanent --add-service=httpd
firewall-cmd --reload

# Install/configure/manage Public Cert infrastructure (Let's Encrypt)



