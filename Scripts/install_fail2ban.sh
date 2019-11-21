#!/bin/bash

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
EOF

cat << EOF > /etc/fail2ban/jail.d/00-sshd.conf
[sshd]
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
enabled = true
EOF

cat << EOF > /etc/fail2ban/jail.d/01-apache-common.conf
[apache-common]

enabled   = true
port      = http,https
filter    = apache-common
logpath   = /var/log/httpd/access_log
maxretry  = 3
findtime  = 360
bantime   = 360
EOF

cat << EOF > /etc/fail2ban/jail.d/02-apache-badbots.conf
[apache-badbots]

enabled  = true
port     = http,https
filter   = apache-badbots
logpath  = /var/log/httpd/error_log
maxretry = 2
EOF
systemctl enable --now fail2ban

