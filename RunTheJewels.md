# Using this REPO

## Build the Bastion 
At this point, it is assumed that you have built the 4 hypervisors (apoc, neo, trinity, and morpheus - as well as, sati and zion)  
Clone this repo on Zion (or whatever host you plan on run the Bastion)
Once the Bastion build is complte, ssh to it, clone this repo, run the post_install.sh (which will reboot node)  
```
# SSH to ZION, Clone this repo, build the Bastion
ssh root@zion.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
./build_KVM.sh RH7-OCP3-BST01

virsh start RH7-OCP3-BST01
ssh root@rh7-ocp3-bst01.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
./post_install.sh 
```

## Deploy OpenShift Container Platform 3
### SSH to Bastion Node
```
ssh root@rh7-ocp3-bst01.matrix.lab
```

### Copy the SSH Key to the Hypervisors
```
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh-copy-id $HYPERVISOR.matrix.lab
done
```

### Reconcile development REPO with all nodes (do this from Bastion)
```
cd ${HOME}/matrix.lab/Scripts
./lab_control.sh gitpull
```

### Provision the OCP3 nodes 
```
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts; nohup ./lab_control.sh build &
EOF
done

for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR "uname -n; virsh list --all"
done
```
### Start the OCP3 nodes 
You need to wait until they are all done being provisioned (they will terminate when installation is complete)
```
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS    
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts; nohup ./lab_control.sh start &
EOF
done
```

### Prepare nodes for OCP3 Software
Once you are certain all of the VMs have started, run the following:
```
INVENTORY="$HOME/matrix.lab/Files/homelab_inventory.yml"
ansible ocp3_hypervisors -i ${INVENTORY} -m shell -a "sudo virsh list --all" 
# If the previous command indicates they are all "running", then...
./OCP3_prep_hosts.sh
# If you want to see it's progress, do the following: 
# ssh rh7-ocp3-bst01.matrix.lab "tail -f /root/install_OCP3.sh.log"
```

### Shutdown VMs and Create Snapshots
```
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo shutdown now -h"; echo "#########################"; done

HYPERVISORS="apoc neo trinity morpheus"
for HOST in $HYPERVISORS; do ssh -t $HOST "matrix.lab/Scripts/lab_control.sh snapshot"; done
```

### Deploy OCP3 Software on nodes (Ansible Playbooks)
This part requires a bit more interactive participation yet.  The process depends on what YOU are trying to do - the following is a faily complex way of calling what *should* be a simple process (there is something wrong with how Gluster is deployed right now)
```
cp ${HOME}/matrix.lab/Files/ocp-3.11-1112*  ~
sed -i -e 's/<rhnuser>/yo/g'  ${HOME}/ocp-3.11-1112*
sed -i -e 's/<rhnpass>/moreyo/g' ${HOME}/*OCS*yml

tmux new -s OCP
rm ~/openshift-ansible.log
BASE="${HOME}/ocp-3.11-1112"
INVENTORY="${BASE}.yml"
LOGDATE=`date +%Y%m%d`; LOGDIR=${HOME}/${LOGDATE}; mkdir -p $LOGDIR; cd $LOGDIR
grep oreg $INVENTORY 
PLAYBOOKS="/usr/share/ansible/openshift-ansible/playbooks/"

#find /usr/share/ansible/openshift-ansible/ -name "config.retry" -exec rm {} \;
#cd ${PLAYBOOKS}

# cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
ansible all -i ${INVENTORY} -a "uptime"

ANSIBLE_OPTIONS=" "
# Run preReqs with full inventory 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}prerequisites.yml $ANSIBLE_OPTIONS | tee ${LOGDIR}/01-prerequistes-`date +%F`.logs &

#####################
# this part is tricky - since I am using the proxy node for both Master/API and app/wildcard traffic, I need to update the proxy
#   as soon as the playbook configures it (see next step)
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}deploy_cluster.yml $ANSIBLE_OPTIONS | tee ${LOGDIR}/02-pbs-deploy_cluster-`date +%F`.logs &

# go to host:  rh7-ocp3-proxy
watch "ls -l /etc/haproxy/haproxy.cfg"
# once the file changes, update the HAproxy Node (if you need to)
# <THISREPO>/Foo/haproxy_update.txt
```

### Rebuild the Joint (Teardown to Deploy OCP)
- Unregister from RHN (or Satellite)
- power off VMs, remove their storage, undefine VMs, remove "storage info" in /etc
- update the hosts from Git
- build the VMs
- start the VMs
```
ssh rh7-ocp3-bst01.matrix.lab
cd matrix.lab/Scripts; git pull
./lab_control.sh gitpull

for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo subscription-manager unregister"; echo ; done

HYPERVISORS="apoc neo trinity morpheus"
for HOST in $HYPERVISORS; do ssh -t $HOST "matrix.lab/Scripts/lab_control.sh teardown"; done
```
Return to 'Deploy OpenShift Container Platform 3' 


## Some Cleanup Bits
```
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}/openshift-metrics/config.yml -e openshift_logging_install_logging=false

# Remove Prometheus
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}/openshift-monitoring/config.yml -e openshift_cluster_monitoring_operator_install=falsE
```

## The HAproxy naunce from above
So - by default, OCP 3 installation can/will deploy a proxy node to accommodate port 443 (basically "app traffic").  Due to my setup at home, which has only one ingress point from the Interwebs, I have opted to use that HAproxy node for ALL traffic (app, management/API, http).  This is accomplished by updating my DNS to use the HAproxy Host IP for the 3 endpoints.  So - if you *don't* update the haproxy, it will not listen, nor forward any traffic and the installer will fail when it attempts to make calls to the API/Management endpoint.  Not a perfect scenario, but - it is worth the extra manual intervention.

