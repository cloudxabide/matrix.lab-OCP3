# Using this REPO

Using this repo  
At this point, it is assumed that you have built the 4 hypervisors (apoc, neo, trinity, and morpheus - as well as, sati and zion)
```
# SSH to ZION, Clone this repo, build the Bastion
ssh root@zion.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }"
./build_KVM.sh RH7-OCP3-BST01

# Once the Bastion build is complte, run the post_install.sh (which will reboot node)
virsh start RH7-OCP3-BST01
ssh root@rh7-ocp3-bst01.matrix.lab
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
./post_install.sh 

# Do some environment tweaking
ssh root@rh7-ocp3-bst01.matrix.lab
cd matrix.lab/Scripts
./lab_control.sh sshcopyid
./lab_control.sh gitpull

# Provision the OCP3 guests on the Hypervisors
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts
    nohup ./lab_control.sh build &
EOF
done

# You need to wait until they are all done being provisioned (they will terminate when complete)
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS    
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts
    nohup ./lab_control.sh start &
EOF
done

# Run the OCP3 Prep script on the VMs from the Bastion 
./OCP3_prep.sh
## If you want to see it's progress, check out
# tail -f /root/install_OCP3.sh.log
```

## Deploy OpenShift on VMs
This part requires a bit more interactive participation.  The process depends on what YOU are trying to do - the following is a faily complex way of calling what *should* be a simple process (there is something wrong with how Gluster is deployed right now)
```
cp ${HOME}/matrix.lab/Files/*2xOCS*.yml ${HOME} 
sed -i -e 's/<rhnuser>/yo/g' ${HOME}/*OCS*yml
sed -i -e 's/<rhnpass>/moreyo/g' ${HOME}/*OCS*yml

INVENTORY="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS.yml"
INVENTORY_NOGLUSTER="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS-noGluster.yml"
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
# Run preReqs with full inventory (will succeed)
nohup ansible-playbook -i ${INVENTORY} playbooks/prerequisites.yml -vvv | tee 01-ocp_prerequisites-`date +%F`.logs &
# Run deploy_cluster with full inventory (will fail with "Task: Check for GlusterFS cluster health / Task: Check for GlusterFS cluster health)
nohup ansible-playbook -i ${INVENTORY} playbooks/deploy_cluster.yml -vvv | tee 02-ocp_deploy_cluster-`date +%F`.logs &
# Run deploy_cluster with Gluster resources removed (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} playbooks/deploy_cluster.yml -vvv | tee 03-ocp_deploy_cluster_noGluster-`date +%F`.logs &
# Run deploy_cluster with Gluster present again (will succeed)
nohup ansible-playbook -i ${INVENTORY} playbooks/openshift-glusterfs/config.yml -vvv | tee 04-ocp_deploy_cluster-`date +%F`.logs &

# NOTE:  this is where things become unclear.... do I just run the full inventory, or do I have to run the remaining playbooks manually/individually
# Run deploy_cluster with full inventory (will succeed)
nohup ansible-playbook -i ~/ocp-3.11-multiple_master_native_ha-2xOCS.yml playbooks/deploy_cluster.yml -vvv | tee 05-ocp_deploy_cluster-noGluster-`date +%F`.logs &
```

Example of how OCP3 *should* be deployed
```
NVENTORY="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS.yml"
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
nohup ansible-playbook -i ${INVENTORY} playbooks/prerequisites.yml -vvv | tee 01-ocp_prerequisites-`date +%F`.logs &
nohup ansible-playbook -i ${INVENTORY} playbooks/deploy_cluster.yml -vvv | tee 02-ocp_deploy_cluster-`date +%F`.logs &
```

