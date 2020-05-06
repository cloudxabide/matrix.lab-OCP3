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
mkdir -p /var/www/vhosts/plex.linuxrevolution.com/ /var/www/html/vhosts/ocp3-mwn.linuxrevolution.com
yum -y install certbot 
wget https://dl.eff.org/certbot-auto
sudo mv certbot-auto /usr/local/bin/certbot-auto
sudo chown root /usr/local/bin/certbot-auto
sudo chmod 0755 /usr/local/bin/certbot-auto


# REDIRECT ALL HTTP TRAFFIC TO HTTPS
cat << EOF > /etc/httpd/conf.d/ocp3-mwn.linuxrevolution.com.conf
<VirtualHost *:80>
  ServerName ocp3-mwn.linuxrevolution.com
  ServerAlias *.ocp3-mwn.linuxrevolution.com

  RewriteEngine On
  RewriteCond %{HTTP_HOST} ^(.+)\.ocp3-mwn\.linuxrevolution\.com$
  RewriteRule ^(.*)$ https://%1.ocp3-mwn.linuxrevolution.com$1 [R=302,L]
</VirtualHost>
EOF
cat << EOF > /etc/httpd/conf.d/linuxrevolution.com.conf
<VirtualHost *:80>
  ServerName linuxrevolution.com
  ServerAlias *.linuxrevolution.com

  RewriteEngine On
  RewriteCond %{HTTP_HOST} ^(.+)\.linuxrevolution\.com$
  RewriteRule ^(.*)$ https://%1.linuxrevolution.com$1 [R=302,L]
</VirtualHost>
EOF
systemctl restart httpd

certbot-auto certonly --server https://acme-v02.api.letsencrypt.org/directory --manual --preferred-challenges dns -d 'linuxrevolution.com,*.linuxrevolution.com,*.ocp3-mwn.linuxrevolution.com'


VHOST="plex.linuxrevolution.com"
# Non-SSL vhost files
cat << EOF > /etc/httpd/conf.d/${VHOST}.conf
<VirtualHost *:80>
ServerAdmin webadmin@${VHOST}
ServerName  ${VHOST}
DocumentRoot /var/www/html/${VHOST}

ErrorLog /var/log/httpd/${VHOST}_error.log
CustomLog /var/log/httpd/${VHOST}_access.log combined
</VirtualHost>
EOF
mkdir -p /var/www/html/${VHOST}

cat << EOF > /var/www/html/plex.linuxrevolution.com/index.html
<HTML><HEAD><TITLE> LinuxRevolution | Plex y'all | &#169 2019</TITLE>
<META http-equiv="refresh" content="1;URL='http://plex.linuxrevolution.com:32400/'">
</HEAD>
<BODY>
Gettin after some Plex Yo...
</BODY>
</HTML>
EOF

# This needs an update to either use html or just a single host entry
certbot-auto certonly --server https://acme-v02.api.letsencrypt.org/directory --manual --preferred-challenges dns -d 'plex.linuxrevolution.com'

## Make this system a BIND host (chicken-egg scenario and I'd like to have 
## DNS available when I am rebuilding the IdM hosts)
yum -y install bind-chroot 
/usr/libexec/setup-named-chroot.sh /var/named/chroot on
systemctl disable named
systemctl start named-chroot
systemctl enable named-chroot

mkdir /var/named/masters; chown named:named $_; chmod 770 $_

touch /var/named/chroot/var/named/data/cache_dump.db
touch /var/named/chroot/var/named/data/named_stats.txt
touch /var/named/chroot/var/named/data/named_mem_stats.txt
touch /var/named/chroot/var/named/data/named.run
mkdir /var/named/chroot/var/named/dynamic
touch /var/named/chroot/var/named/dynamic/managed-keys.bind

restorecon -RFvv /var/named/

chmod -R 777 /var/named/chroot/var/named/data
chmod -R 777 /var/named/chroot/var/named/dynamic

cp /var/named/chroot/etc/named.conf /var/named/chroot/etc/named.conf.orig
sed -i -e 's/127.0.0.1/any/'g /etc/named.conf
sed -i -e 's/localhost/any/g' /etc/named.conf


cat << EOF >> /var/named/chroot/etc/named.conf

#  ZONES FOR LinuxRevolution.com
zone "linuxrevolution.com" {
    type master;
    file "masters/linuxrevolution.com.zone";
};
zone "cloudapps.linuxrevolution.com" {
    type master;
    file "masters/cloudapps.linuxrevolution.com.zone";
};
EOF

cat << EOF > /var/named/masters/linuxrevolution.com.zone
\$TTL 86400
@       IN      SOA     linuxrevolution.com. hostmaster.linuxrevolution.com. (
                               2014101901      ; Serial
                               43200      ; Refresh
                               3600       ; Retry
                               3600000    ; Expire
                               2592000 )  ; Minimum

;       Define the nameservers and the mail servers

               IN      NS      ns1.linuxrevolution.com.
	IN	A	174.53.251.89
*	IN	A	174.53.251.89
ns1	IN	A	172.30.0.202
zion	IN	A	174.53.251.89
www	IN	CNAME	zion	
EOF

cat << EOF > /var/named/masters/cloudapps.linuxrevolution.com.zone
\$TTL 86400
@       IN      SOA     cloudapps.linuxrevolution.com. hostmaster.linuxrevolution.com. (
                               2014101901      ; Serial
                               43200      ; Refresh
                               3600       ; Retry
                               3600000    ; Expire
                               2592000 )  ; Minimum

;       Define the nameservers and the mail servers

               IN      NS      ns1.cloudapps.linuxrevolution.com.
	IN	A	174.53.251.89
*	IN	A	174.53.251.89
ns1     IN      A       172.30.0.202
EOF

chown named:named /var/named/chroot/var/named/masters/*
restorecon -Fvv /var/named/chroot/var/named/*

