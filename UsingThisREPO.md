# Using this REPO

## Build the Bastion 
At this point, it is assumed that you have built the 4 hypervisors (apoc, neo, trinity, and morpheus - as well as, sati and zion)  
Clone this repo on Zion (or whatever host you plan on run the Bastion)
Once the Bastion build is complte, ssh to it, clone this repo, run the post_install.sh (which will reboot node)  
```
# SSH to ZION, Clone this repo, build the Bastion
ssh root@zion.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }"
./build_KVM.sh RH7-OCP3-BST01

virsh start RH7-OCP3-BST01
ssh root@rh7-ocp3-bst01.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
./post_install.sh 
```

## Deploy OpenShift Container Platform 3
### Reconcile development REPO with all nodes
```
ssh root@rh7-ocp3-bst01.matrix.lab
cd matrix.lab/Scripts
./lab_control.sh sshcopyid
./lab_control.sh gitpull
```

### Provision the OCP3 nodes 
```
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR "cd ~/matrix.lab/Scripts; nohup ./lab_control.sh build &"
done
```
### Start the OCP3 guests
You need to wait until they are all done being provisioned (they will terminate when complete)
```
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS    
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts
    nohup ./lab_control.sh start &
EOF
done
```

### Prepare nodes for OCP3 Software
```
./OCP3_prep.sh
# If you want to see it's progress, check out
# ssh rh7-ocp3-bst01.matrix.lab "tail -f /root/install_OCP3.sh.log"
```

### Deploy OCP3 Software on nodes (Ansible Playbooks)
This part requires a bit more interactive participation yet.  The process depends on what YOU are trying to do - the following is a faily complex way of calling what *should* be a simple process (there is something wrong with how Gluster is deployed right now)
```
cp ${HOME}/matrix.lab/Files/*2xOCS*.yml ${HOME} 
sed -i -e 's/<rhnuser>/yo/g' ${HOME}/*OCS*yml
sed -i -e 's/<rhnpass>/moreyo/g' ${HOME}/*OCS*yml

INVENTORY="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS.yml"
INVENTORY_NOGLUSTER="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS-noGluster.yml"
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
# Run preReqs with full inventory (will succeed)
nohup ansible-playbook -i ${INVENTORY} playbooks/prerequisites.yml -vvv | tee 01-pbs-prerequisites-`date +%F`.logs &
# Run deploy_cluster with full inventory (will fail with "Task: Check for GlusterFS cluster health / Task: Check for GlusterFS cluster health)
nohup ansible-playbook -i ${INVENTORY} playbooks/deploy_cluster.yml -vvv | tee 02-pbs-deploy_cluster-`date +%F`.logs &
# Run deploy_cluster with Gluster resources removed (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} playbooks/deploy_cluster.yml -vvv | tee 03-pbs-deploy_cluster_noGluster-`date +%F`.logs &
# Run deploy_cluster with Gluster present again (will succeed)
nohup ansible-playbook -i ${INVENTORY} playbooks/openshift-glusterfs/config.yml -vvv | tee 04-ocp_deploy_cluster-`date +%F`.logs &

# Everything to this point *should* have worked, the remaining steps may still be elusive
# Run deploy_cluster with full inventory (will succeed)
nohup ansible-playbook -i ~/ocp-3.11-multiple_master_native_ha-2xOCS.yml playbooks/deploy_cluster.yml -vvv | tee 05-ocp_deploy_cluster-`date +%F`.logs &
```

Example of how OCP3 *should* be deployed
```
NVENTORY="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS.yml"
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
nohup ansible-playbook -i ${INVENTORY} playbooks/prerequisites.yml -vvv | tee 01-ocp_prerequisites-`date +%F`.logs &
nohup ansible-playbook -i ${INVENTORY} playbooks/deploy_cluster.yml -vvv | tee 02-ocp_deploy_cluster-`date +%F`.logs &
```
### Update the Users login credentials
```
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
```

### Teardown
- Unregister from RHN
- power off VMs, remove their storage, undefine VMs, remove "storage info" in /etc

```
ssh rh7-ocp3-bst01.matrix.lab
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo subscription-manager unregister"; echo ; done

HYPERVISORS="apoc neo trinity morpheus"
for HOST in $HYPERVISORS; do ssh -t $HOST "matrix.lab/Scripts/lab_control.sh teardown "; done
```
