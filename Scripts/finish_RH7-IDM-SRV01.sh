#!/bin/bash

# You liklely still need to cut-and-paste this thing in to a shell.
#   But... it IS close to being executable as a stand-alone!
ADMINPASSWD='Passw0rd'

# Update the firewall settings according to installation doc
DEFAULTZONE=$(firewall-cmd --get-default-zone)
firewall-cmd --permanent --zone=${DEFAULTZONE} --add-port={80/tcp,123/tcp,443/tcp,389/tcp,636/tcp,88/tcp,88/udp,464/tcp,464/udp,53/tcp,53/udp,123/udp,7389/tcp}
firewall-cmd --permanent --zone=${DEFAULTZONE} --add-service={ntp,freeipa-ldap,freeipa-ldaps,dns} 
firewall-cmd --reload
firewall-cmd --list-ports
firewall-cmd --list-all

# Install the IDM packages
yum -y install ipa-server bind bind-dyndb-ldap ipa-server-dns

# The following are the installation tasks, which are different depending on the host
case `hostname -s` in
  # MASTER - Run this first...
  rh7-idm-srv01)
# Use --no-ntp for IPA/IDM (Sec 2.4.6 from Install Guide)
IPA_OPTIONS="
--realm=MATRIX.LAB
--domain=matrix.lab
--ds-password=Passw0rd
--admin-password=Passw0rd
--hostname=rh7-idm-srv01.matrix.lab
--ip-address=10.10.10.121
--setup-dns --no-forwarders
--mkhomedir
--unattended"

CERTIFICATE_OPTIONS="
--subject="

echo "NOTE:  You are likely going to see a warning/notice about entropy"
echo "  in another window, run:  rngd -r /dev/urandom -o /dev/random -f"

echo "ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS"
ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS
echo $ADMINPASSWD | kinit admin
klist

echo "You will likely want to add the entry to the RH7IDM01 DNS zone for RH7IDM02 before this next step"
ipa dnszone-add 10.10.10.in-addr.arpa.  # "public"
ipa dnszone-add 10.16.172.in-addr.arpa. # storage
ipa dnsrecord-add matrix.lab rh7-idm-srv01 --a-rec 10.10.10.121
ipa dnsrecord-add matrix.lab rh7-idm-srv02 --a-rec 10.10.10.122
ipa dnsrecord-add matrix.lab rh7-idm-srv03 --a-rec 10.10.10.123
ipa dnsrecord-add 10.10.10.in-addr.arpa 120 --ptr-rec rh7-idm-srv.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 121 --ptr-rec rh7-idm-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 122 --ptr-rec rh7-idm-srv02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 123 --ptr-rec rh7-idm-srv03.matrix.lab.

# These entries are for any additional IdM Servers in the environment.
ipa host-add rh7-idm-srv02.matrix.lab --random
ipa host-add rh7-idm-srv03.matrix.lab --random
ipa hostgroup-add-member ipaservers --hosts rh7-idm-srv02.matrix.lab
ipa hostgroup-add-member ipaservers --hosts rh7-idm-srv03.matrix.lab
  ;;
  rh7-idm-srv02)
    ADMINPASSWD='Passw0rd'
    ipa-replica-install --principal admin --realm=MATRIX.LAB --domain=matrix.lab --setup-dns --no-forwarders --admin-password ${ADMINPASSWD}
    # Or.. use the random password from above
    #ipa-replica-install --principal admin --realm=MATRIX.LAB --domain=matrix.lab --setup-dns --no-forwarders --password ${ADMINPASSWD}
  ;;
  *)
    echo "DUDE!  This system is not part of the borg"
    exit 0
 ;;
esac

case `hostname -s` in 
  rh7-idm-srv01)
authconfig --enablemkhomedir --update
echo "$ADMINPASSWD" | kinit
# THIS IS SPECIFIC TO MY HOME - it allows zone-transfer and "host -l matrix.lab" to run
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' matrix.lab

###############
# User/Group Management
###############
echo "Passw0rd" | ipa user-add morpheus --uid=1000 --gidnumber=1000 --first=Morpheus --last=McChicken --email=morpheus@matrix.lab --homedir=/home/morpheus --shell=/bin/bash --password
echo "Passw0rd" | ipa user-add jradtke --uid=2025 --gidnumber=2025 --first=James --last=Radtke --manager=Morpheus --email=jradtke@matrix.lab --homedir=/home/jradtke --shell=/bin/bash --password
## NOTE: NEED TO PUT THESE IN TO "ipa" COMMANDS
GROUPS="admins managers"
for GROUP in $GROUPS
do 
  ipa group-add $GROUP
done

###############
## Service Account Management
###############
# For RHV
ipa group-add kvm --gid 36
ipa user-add vdsm --uid=36 --gidnumber=36 --first=Virtualization --last=Manager --gecos="Node Virtualization Manager" --email=vdsm@matrix.lab --homedir=/var/lib/vdsm --shell=/sbin/nologin --random
ipa user-add qemu --uid=107 --gidnumber=107 --first=qemu --last=user --gecos="qemu user" --email=qemu@matrix.lab --homedir=/ --shell=/sbin/nologin --random
 
###############
# PHYSICAL NODES
###############
# Network Gear
ipa dnsrecord-add matrix.lab sophos-xg          --a-rec 10.10.10.1
ipa dnsrecord-add matrix.lab firewall           --cname-rec='sophos-xg.matrix.lab.'
ipa dnsrecord-add matrix.lab gateway            --cname-rec='sophos-xg.matrix.lab.'
ipa dnsrecord-add matrix.lab cisco-sg300-28     --a-rec 10.10.10.2
ipa dnsrecord-add matrix.lab switch             --cname-rec='cisco-sg300-28.matrix.lab.'
# Physical Computers
ipa dnsrecord-add matrix.lab zion               --a-rec 10.10.10.10
ipa dnsrecord-add matrix.lab zion-storage       --a-rec 172.16.10.10
ipa dnsrecord-add matrix.lab neo                --a-rec 10.10.10.11
ipa dnsrecord-add matrix.lab neo-storage        --a-rec 172.16.10.11
ipa dnsrecord-add matrix.lab neo-ilom           --a-rec 10.10.10.21
ipa dnsrecord-add matrix.lab trinity            --a-rec 10.10.10.12
ipa dnsrecord-add matrix.lab trinity-storage    --a-rec 172.16.10.12
ipa dnsrecord-add matrix.lab trinity-ilom       --a-rec 10.10.10.22
ipa dnsrecord-add matrix.lab morpheus           --a-rec 10.10.10.13
ipa dnsrecord-add matrix.lab morpheus-storage   --a-rec 172.16.10.13
ipa dnsrecord-add matrix.lab morpheus-ilom      --a-rec 10.10.10.23
ipa dnsrecord-add matrix.lab sati               --a-rec 10.10.10.17
ipa dnsrecord-add matrix.lab sati-storage       --a-rec 172.16.10.17
ipa dnsrecord-add matrix.lab apoc		--a-rec 10.10.10.18
ipa dnsrecord-add matrix.lab apoc-storage       --a-rec 172.16.10.18
ipa dnsrecord-add matrix.lab seraph             --a-rec 10.10.10.19
ipa dnsrecord-add matrix.lab seraph-storage     --a-rec 172.16.10.19
ipa dnsrecord-add matrix.lab storage            --cname-rec='seraph-storage.matrix.lab.'
ipa dnsrecord-add matrix.lab nas                --cname-rec='seraph-storage.matrix.lab.'
ipa dnsrecord-add matrix.lab freenas                --cname-rec='seraph-storage.matrix.lab.'
ipa dnsrecord-add matrix.lab dock-dell          --a-rec 10.10.10.30
ipa dnsrecord-add matrix.lab dock-thinkpad	--a-rec 10.10.10.31

# REVERSE LOOKUP 
# 10.10.10
ipa dnsrecord-add 10.10.10.in-addr.arpa 1       --ptr-rec sophos-xg.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 2       --ptr-rec cisco-sg300-28.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 10      --ptr-rec zion.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 11      --ptr-rec neo.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 12      --ptr-rec trinity.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 13      --ptr-rec morpheus.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 18      --ptr-rec apoc.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 19      --ptr-rec seraph.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 21      --ptr-rec neo-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 22      --ptr-rec trinity-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 23      --ptr-rec morpheus-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 30      --ptr-rec dock-dell.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 31      --ptr-rec dock-thinkpad.matrix.lab.
# 10.16.172
ipa dnsrecord-add 10.16.172.in-addr.arpa 10     --ptr-rec zion-storage.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 11     --ptr-rec neo-storage.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 12     --ptr-rec trinity-storage.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 13     --ptr-rec morpheus-storage.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 18     --ptr-rec apoc-storage.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 19     --ptr-rec seraph-storage.matrix.lab.
###############
# Utility Hosts 
###############
ipa dnsrecord-add matrix.lab websrv             --a-rec 10.10.10.20
ipa dnsrecord-add matrix.lab rh8-util-srv01     --a-rec 10.10.10.100
ipa dnsrecord-add matrix.lab rh7-sat6-srv01     --a-rec 10.10.10.102
ipa dnsrecord-add matrix.lab rh7-sat6-cap01     --a-rec 10.10.10.103
ipa dnsrecord-add matrix.lab rh7-rhv4-mgr01     --a-rec 10.10.10.104
ipa dnsrecord-add matrix.lab rh7-cfme-srv01     --a-rec 10.10.10.105
ipa dnsrecord-add matrix.lab rh7-ans-srv01      --a-rec 10.10.10.107
ipa dnsrecord-add matrix.lab rh7-lms-srv01      --a-rec 10.10.10.110
ipa dnsrecord-add matrix.lab librenms           --cname-rec='rh7-lms-srv01'
ipa dnsrecord-add matrix.lab rh7-jenkins-srv01  --a-rec 10.10.10.111
ipa dnsrecord-add matrix.lab jenkins            --cname-rec='rh7-jenkins-srv01'
ipa dnsrecord-add 10.10.10.in-addr.arpa 20      --ptr-rec websrv.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 100     --ptr-rec rh8-util-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 102     --ptr-rec rh7-sat6-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 103     --ptr-rec rh7-sat6-cap01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 104     --ptr-rec rh7-rhv4-mgr01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 105     --ptr-rec rh7-cfme-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 107     --ptr-rec rh7-ans-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 110     --ptr-rec rh7-lms-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 111     --ptr-rec rh7-jenkins-srv01.matrix.lab.
###############
# VPN Endpoints 
###############
ipa dnsrecord-add matrix.lab vpn-guest-01       --a-rec 10.10.10.241
ipa dnsrecord-add matrix.lab vpn-guest-02       --a-rec 10.10.10.242
ipa dnsrecord-add matrix.lab vpn-guest-03       --a-rec 10.10.10.243
ipa dnsrecord-add 10.10.10.in-addr.arpa 241     --ptr-rec vpn-guest-01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 242     --ptr-rec vpn-guest-02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 243     --ptr-rec vpn-guest-03.matrix.lab.
####################
# OCP Hosts
####################
ipa dnsrecord-add matrix.lab rh7-ocp3-mst    --a-rec 10.10.10.170
ipa dnsrecord-add matrix.lab openshift       --cname-rec='rh7-ocp3-mst.matrix.lab.'
ipa dnsrecord-add matrix.lab ocp3            --cname-rec='rh7-ocp3-mst.matrix.lab.'
ipa dnsrecord-add matrix.lab api             --cname-rec='rh7-ocp3-mst.matrix.lab.'
ipa dnsrecord-add matrix.lab rh7-ocp3-mst01  --a-rec 10.10.10.171
ipa dnsrecord-add matrix.lab rh7-ocp3-mst02  --a-rec 10.10.10.172
ipa dnsrecord-add matrix.lab rh7-ocp3-mst03  --a-rec 10.10.10.173
ipa dnsrecord-add matrix.lab rh7-ocp3-inf01  --a-rec 10.10.10.175
ipa dnsrecord-add matrix.lab rh7-ocp3-inf02  --a-rec 10.10.10.176
ipa dnsrecord-add matrix.lab rh7-ocp3-inf03  --a-rec 10.10.10.177
ipa dnsrecord-add matrix.lab rh7-ocp3-app01  --a-rec 10.10.10.181
ipa dnsrecord-add matrix.lab rh7-ocp3-app02  --a-rec 10.10.10.182
ipa dnsrecord-add matrix.lab rh7-ocp3-app03  --a-rec 10.10.10.183
ipa dnsrecord-add matrix.lab rh7-ocp3-bst01  --a-rec 10.10.10.189
# OCP Hosts (Reverse)
ipa dnsrecord-add 10.10.10.in-addr.arpa 170  --ptr-rec rh7-ocp3-mst.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 171  --ptr-rec rh7-ocp3-mst01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 172  --ptr-rec rh7-ocp3-mst02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 173  --ptr-rec rh7-ocp3-mst02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 175  --ptr-rec rh7-ocp3-inf01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 176  --ptr-rec rh7-ocp3-inf02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 177  --ptr-rec rh7-ocp3-inf02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 181  --ptr-rec rh7-ocp3-app01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 182  --ptr-rec rh7-ocp3-app02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 183  --ptr-rec rh7-ocp3-app03.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 189  --ptr-rec rh7-ocp3-bst01.matrix.lab.

# OCP tertiary domain (point at the Infra Nodes - routers) 
# DomainName: Openshift Container Platform 3 - MidWest North (ocp3-mwn)
ipa dnszone-add ocp3-mwn.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add ocp3-mwn.matrix.lab '*' --a-rec 10.10.10.175 
ipa dnsrecord-add ocp3-mwn.matrix.lab '*' --a-rec 10.10.10.176 
ipa dnsrecord-add ocp3-mwn.matrix.lab '*' --a-rec 10.10.10.177 

# Add an internal reference that refers to the external zone
### LINUXREVOLUTION.com
ipa dnszone-add linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true --skip-overlap-check
ipa dnsrecord-add linuxrevolution.com 'ocp3-console' --a-rec 10.10.10.170

### OCP-MWN.LINUXREVOLUTION.com
ipa dnszone-add ocp3-mwn.linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add ocp3-mwn.linuxrevolution.com '*' --a-rec 10.10.10.175
ipa dnsrecord-add ocp3-mwn.linuxrevolution.com '*' --a-rec 10.10.10.176
ipa dnsrecord-add ocp3-mwn.linuxrevolution.com '*' --a-rec 10.10.10.177

  ;;
esac

exit 0
 
########################################################################################
########################################################################################
#                                                                                      #
#     FFFFFF    IIIIIII   N      N    IIIIIII    SSS    H      H  EEEEEE   DDDD        #
#     F            I      N N    N       I      S   S   H      H  E        D   D       #
#     F            I      N  N   N       I      S       H      H  E        D    D      #
#     FFFF         I      N   N  N       I       SSS    HHHHHHHH  EEEE     D    D      #
#     F            I      N    N N       I          S   H      H  E        D    D      #
#     F            I      N     NN       I      S   S   H      H  E        D   D       # 
#     F         IIIIIII   N      N    IIIIIII    SSS    H      H  EEEEEE   DDDD        #
#                                                                                      #
########################################################################################
########################################################################################
#  Some update foo for schema/policy
#  ipa pwpolicy-mod global_policy --lockouttime=0

# ldapsearch -x -LLL -D "cn=Directory Manager" -w directory "cn=global_policy"
# uname -n; echo "* * * * * * *"; ipa pwpolicy-show; echo "* * * * *"; ldapsearch -xLLL -D "cn=Directory Manager" -W -b "dc=MATRIX,dc=LAB" uid=jradtke krbloginfailedcount; echo "* * * * "; ipa user-status jradtke 

# If you need to re-install an IDM box...
# ipa-replica-manage del rh7-idm-srv02.matrix.lab --force

# Appendix to meld Satellite 6 in to the fold...
  ## On RH7-IDM-SRV01...
echo Passw0rd | kinit admin
ipa host-add --desc="Satellite 6" --locality="Washington, DC" --location="LaptopLab" --os="Red Hat Enterprise Linux Server 7" --password=Passw0rd rh7-sat6-srv01.matrix.lab
ipa service-add HTTP/rh7-sat6-srv01.matrix.lab@matrix.lab

dig SRV _kerberos._tcp.matrix.lab | grep -v \;
dig SRV _ldap._tcp.matrix.lab | grep -v \;

# Example DNS update
; ldap servers
_ldap._tcp		IN SRV 0 100 389	rh7-idm-srv01
_ldap._tcp		IN SRV 0 90  389	rh7-idm-srv02

;kerberos realm
_kerberos		IN TXT MATRIX.LAB

; kerberos servers
_kerberos._tcp		IN SRV 0 100 88		rh7-idm-srv01
_kerberos._udp		IN SRV 0 100 88		rh7-idm-srv01
_kerberos-master._tcp	IN SRV 0 100 88		rh7-idm-srv01
_kerberos-master._udp	IN SRV 0 100 88		rh7-idm-srv01
_kpasswd._tcp		IN SRV 0 100 464	rh7-idm-srv01
_kpasswd._udp		IN SRV 0 100 464	rh7-idm-srv01
_kerberos._tcp          IN SRV 0 90 88         rh7-idm-srv02
_kerberos._udp          IN SRV 0 90 88         rh7-idm-srv02
_kerberos-master._tcp   IN SRV 0 90 88         rh7-idm-srv02
_kerberos-master._udp   IN SRV 0 90 88         rh7-idm-srv02
_kpasswd._tcp           IN SRV 0 90 464        rh7-idm-srv02
_kpasswd._udp           IN SRV 0 90 464        rh7-idm-srv02

; CNAME for IPA CA replicas (used for CRL, OCSP)
ipa-ca			IN A			10.10.10.121
ipa-ca			IN A			10.10.10.122
