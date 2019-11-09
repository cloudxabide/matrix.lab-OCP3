# Install libreNMS

## Overview should be quick/painless to get libreNMS running on a CentOS 7 EC2 instance

NOTE:  EPEL is only released for EL 7 at this time (2019-06-07).  I don't feel like figuring out how to make libreNMS work on EL 8, or on RHEL... for that matter.

Search for "Red Hat Enterprise Linux" in the Amazon Marketplace (or pick whatever you want)  

```
ssh -i ~/.ssh/blah.pem centos@(ip) # No clue why this is not more "AWS" normalized?
sudo su -
yum -y update && shutdown now -r
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install  https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum -y install composer cronie fping git httpd ImageMagick jwhois mariadb mariadb-server mtr MySQL-python net-snmp net-snmp-utils nmap php72w php72w-cli php72w-common php72w-curl php72w-gd php72w-mbstring php72w-mysqlnd php72w-process php72w-snmp php72w-xml php72w-zip python-memcached rrdtool
useradd librenms -d /opt/librenms -M -r
usermod -a -G librenms apache
cd /opt
composer create-project --no-dev --keep-vcs librenms/librenms librenms dev-master
cd -

# I still need to figure this out...
cat << EOF > mysql.cmds
CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'librenms'@'localhost' IDENTIFIED BY 'Passw0rd';
GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
FLUSH PRIVILEGES;
exit
EOF
systemctl enable mariadb --now
mysql -u root < mysql.cmds
systemctl restart mariadb

# Update MySQL/MariaDB 
cp /etc/my.cnf /etc/my.cnf-`date +%F`
sed -i -e 's/^\[mysqld_safe\]/innodb_file_per_table=1\nlower_case_table_names=0\n\n\[mysqld_safe\]/g' /etc/my.cnf

cp /etc/php.ini /etc/php.ini-`date +%F`
sed -i -e 's/;date.timezone =/date.timezone = America\/Chicago/g' /etc/php.ini
cd /etc/; rm -f localtime
ln -s ../usr/share/zoneinfo/America/Chicago localtime
cd -

cat << EOF > /etc/httpd/conf.d/librenms.conf
<VirtualHost *:80>
  DocumentRoot /opt/librenms/html/
  ServerName  librenms.linuxrevolution.com

  AllowEncodedSlashes NoDecode
  <Directory "/opt/librenms/html/">
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>
</VirtualHost>
EOF
echo "`ip addr s eth0 | grep "inet " | awk '{ print $2 }' | sed 's/\/24//g'` librenms.linuxrevolution.com" >> /etc/hosts
sed -i -e 's/#ServerName www.example.com:80/ServerName librenms.matrix.lab:80/g' /etc/httpd/conf/httpd.conf

mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.disabled
systemctl enable httpd --now

yum -y install policycoreutils-python
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?'
restorecon -RFvv /opt/librenms/logs/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?'
restorecon -RFvv /opt/librenms/rrd/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/storage(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/storage(/.*)?'
restorecon -RFvv /opt/librenms/storage/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/bootstrap/cache(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/bootstrap/cache(/.*)?'
restorecon -RFvv /opt/librenms/bootstrap/cache/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/cache(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/cache(/.*)?'
restorecon -RFvv /var/www/opt/librenms/cache/
setsebool -P httpd_can_sendmail=1

cat << EOF > http_fping.tt
module http_fping 1.0;

require {
type httpd_t;
class capability net_raw;
class rawip_socket { getopt create setopt write read };
}

#============= httpd_t ==============
allow httpd_t self:capability net_raw;
allow httpd_t self:rawip_socket { getopt create setopt write read };
EOF

checkmodule -M -m -o http_fping.mod http_fping.tt
semodule_package -o http_fping.pp -m http_fping.mod
semodule -i http_fping.pp

mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf-`date +%F`
cat << EOF > /etc/snmp/snmpd.conf
# Added for matrix.lab SNMP monitoring
syslocation basement
syscontact Root <root@localhost>
dontLogTCPWrappersConnects yes

com2sec local     localhost       COMMUNITY
com2sec matrixlab NETWORK/24      publicRO

##     group.name sec.model  sec.name
#group MyROGroup  any        matrixlab

##           incl/excl subtree                          mask
view all    included  .1                               80

##                context sec.model sec.level prefix read   write  notif
access MyROGroup ""      any       noauth    0      all    none   none
EOF
restorecon -Fvv /etc/snmp/snmpd.conf
systemctl enable snmpd
systemctl restart snmpd

cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

chown -R librenms:librenms /opt/librenms
chmod 770 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ /opt/librenms/cache
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ /opt/librenms/cache

firewall-cmd --permanent --add-service={http,https}
firewall-cmd --reload

su - librenms
./scripts/composer_wrapper.php install --no-dev
exit

touch /opt/librenms/config.php
chown librenms:librenms /opt/librenms/config.php

```

## Testing
```
yum -y install net-snmp net-snmp-utils
snmpwalk -v2c -c publicRO 10.10.10.1
```

libr3nmsP...
-?qVv&qj7Sz(Qf47jac%-v*GjXtO?sl7
