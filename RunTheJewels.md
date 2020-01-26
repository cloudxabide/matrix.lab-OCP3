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
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts; nohup ./lab_control.sh build &
EOF
done

for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR "uname -n; virsh list --all"
done
```
### Start the OCP3 guests
You need to wait until they are all done being provisioned (they will terminate when complete)
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
cp ${HOME}/matrix.lab/Files/*2xOCS*.yml ${HOME} 
sed -i -e 's/<rhnuser>/yo/g' ${HOME}/*OCS*yml
sed -i -e 's/<rhnpass>/moreyo/g' ${HOME}/*OCS*yml

BASE="${HOME}/ocp-3.11-1112"
INVENTORY="${BASE}.yml"
INVENTORY_NOGLUSTER="${BASE}-noGluster.yml"
LOGDATE=`date +%Y%m%d`; LOGDIR=${HOME}/${LOGDATE}; mkdir -p $LOGDIR; cd $LOGDIR
grep oreg $INVENTORY $INVENTORY_NOGLUSTER
PLAYBOOKS="/usr/share/ansible/openshift-ansible/playbooks/"
rm ~/openshift-ansible.log

#find /usr/share/ansible/openshift-ansible/ -name "config.retry" -exec rm {} \;
#cd ${PLAYBOOKS}

# cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
# Run preReqs with full inventory (will succeed)
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}prerequisites.yml -vvv | tee ${LOGDIR}/01-pbs-prerequisites-`date +%F`.logs &
#####################
# https://docs.okd.io/3.11/install_config/persistent_storage/persistent_storage_glusterfs.html#install-example-full
# Run deploy_cluster with resources removed (Gluster, logging, metrics) (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} ${PLAYBOOKS}deploy_cluster.yml -vvv | tee ${LOGDIR}/02-pbs-deploy_cluster_noGluster-`date +%F`.logs &

# Run deploy_cluster with Gluster present again (will succeed), then a health check
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-glusterfs/config.yml -vvv | tee ${LOGDIR}/03-pbs_deploy_glusterfs-`date +%F`.logs &

# Go run Foo/all_the_playbooks.sh
#  which have single digit numerical prefix and the name of the playbook in the log filename
sh ~/matrix.lab/Foo/all_the_playbooks.sh

nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-checks/health.yml -vvv | tee ${LOGDIR}/05-pbs-healthcheck-`date +%F`.logs &

#################################################################
# THE FOLLOWING DOES NOT SEEM TO WORK
# http://people.redhat.com/jrivera/openshift-docs_preview/openshift-origin/glusterfs-review/install_config/persistent_storage/persistent_storage_glusterfs.html#install-example-full
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-logging/config.yml -vvv | tee ${LOGDIR}/04a-pbs_openshift-logging-`date +%F`.logs
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-metrics/config.yml -vvv | tee ${LOGDIR}/04b-pbs_openshift-metrics-`date +%F`.logs
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}metrics-server/config.yml -vvv | tee ${LOGDIR}/04c-pbs_metrics-server-`date +%F`.logs
#################################################################

```
Once that is done.. I need to create endpoints and redeploy the logging pods after modifying the memory requirement oc edit dc -n openshift-logging 
% s/16Gi/2Gi/g



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

for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts; nohup ./lab_control.sh build &
EOF
done

for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts; nohup ./lab_control.sh start &
EOF
done

for HOST in $HYPERVISORS; do ssh -t $HOST "sudo virsh list --all | grep OCP"; done
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo uptime"; done
```

## OCP3 URLs
https://ocp3-console.linuxrevolution.com:8443/console/   
https://hawkular.ocp3-mwn.linuxrevolution.com  
https://cluster-console.ocp3-mwn.linuxrevolution.com/  

https://registry-console-default.ocp3-mwn.linuxrevolution.com/registry  
https://docker-registry-default.ocp3-mwn.linuxrevolution.com/
