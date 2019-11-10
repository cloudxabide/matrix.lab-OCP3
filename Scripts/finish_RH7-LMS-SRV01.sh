

# Install/configure CertBOT (for Let's Encrypt)

subscription-manager repos --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-optional-rpms
yum -y install certbot python2-certbot-apache

cd /opt
git clone https://github.com/certbot/certbot.git
cd certbot && ./certbot-auto

yum -y install letsencrypt

cat << EOF > /etc/httpd/conf.d/ocp3-mwn.linuxrevolution.com.conf
<VirtualHost *:80>
  DocumentRoot /var/www/html/vhosts/ocp3-mwn.linuxrevolution.com
  ServerName  test.ocp3-mwn.linuxrevolution.com

  AllowEncodedSlashes NoDecode
  <Directory "/var/www/html/vhosts/ocp3-mwn.linuxrevolution.com">
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>
</VirtualHost>
EOF
systemctl restart httpd

# For the webserver
mkdir /var/www/vhosts/
echo "/var/www/vhosts/rideandabide.com/" | ./certbot-auto certonly -d rideandabide.com --webroot 
echo "/var/www/vhosts/mediawiki/" | ./certbot-auto certonly -d linuxrevolution.com --webroot 
echo "/var/www/vhosts/mediawiki/" | ./certbot-auto certonly -d www.linuxrevolution.com --webroot 
echo "/var/www/vhosts/ocp3-mwn.linuxrevolution.com/" | ./certbot-auto --email cloudxabide@gmail.com --webroot --agree-tos -d *.ocp3-mwn.linuxrevolution.com 

#./certbot-auto certonly -d plex.linuxrevolution.com --webroot

# For the following, provide a passphrase you don't mind entering in the Plex config
openssl pkcs12 -export -out ~/plex_linuxrevolution_com.pfx \
  -inkey /etc/letsencrypt/live/plex.linuxrevolution.com/privkey.pem \
  -in /etc/letsencrypt/live/plex.linuxrevolution.com/cert.pem \
  -certfile /etc/letsencrypt/live/plex.linuxrevolution.com/chain.pem
# Or... run
# ./create_plex_pfx.exp

exit 0

# SCP file to helios:/Users/jradtke/Music/ to be read by Plex.
# scp root@websrv.matrix.lab:/root/plex_linuxrevolution_com.pfx Music/
# openssl pkcs12 -in /Users/jradtke/Music/plex_linuxrevolution_com.pfx -out /Users/jradtke/Music/plex_linuxrevolution_com.pem -nodes
# openssl x509 -in /Users/jradtke/Music/plex_linuxrevolution_com.pem -text -noout

helios:.ssh jradtke$ scp -i ~/.ssh/id_rsa-forplex root@10.10.10.20:plex_linuxrevolution_com.pfx ~/Music/
helios:.ssh jradtke$ scp -i ~/.ssh/id_rsa-forplex root@10.10.10.20:/etc/letsencrypt/live/plex.linuxrevolution.com/chain.pem ~/Music/plex_linuxrevolution_com.pem
