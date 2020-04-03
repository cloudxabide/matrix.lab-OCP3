# Cluster Build Manual

```
tmux new -s OCP
rm ~/openshift-ansible.log
BASE="${HOME}/ocp-3.11-1112"
INVENTORY="${BASE}.yml"
INVENTORY_NOGLUSTER="${BASE}-noGluster.yml"
LOGDATE=`date +%Y%m%d`; LOGDIR=${HOME}/${LOGDATE}; mkdir -p $LOGDIR; cd $LOGDIR
grep oreg $INVENTORY $INVENTORY_NOGLUSTER
PLAYBOOKS="/usr/share/ansible/openshift-ansible/playbooks/"

find /usr/share/ansible/openshift-ansible/ -name "config.retry" -exec rm {} \;
#cd ${PLAYBOOKS}

# cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY}
# Run preReqs with full inventory (will succeed)
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}prerequisites.yml -vvv | tee ${LOGDIR}/01-prerequistes-`date +%F`.logs &

#####################
# https://docs.okd.io/3.11/install_config/persistent_storage/persistent_storage_glusterfs.html#install-example-full
# Run deploy_cluster with resources removed (Gluster, logging, metrics) (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} ${PLAYBOOKS}deploy_cluster.yml -vvv | tee ${LOGDIR}/02-pbs-deploy_cluster_noGluster-`date +%F`.logs &

# Run deploy_cluster with Gluster present again (will succeed), then a health check
nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-glusterfs/config.yml -vvv | tee ${LOGDIR}/03-pbs_deploy_glusterfs-`date +%F`.logs &

# Update the HAproxy Node (if you need to)
# <THISREPO>/Foo/haproxy_update.txt

# Update the Storage Endpoints using <THISREPO>/Foo/post_install_tasks.md
# then return here

# run Foo/all_the_playbooks.sh
#  which have single digit numerical prefix and the name of the playbook in the log filename
sh ~/matrix.lab/Foo/all_the_playbooks.sh
# there is a script that updates the proxy (again), which means you also need to update the proxy (again) from the process above

nohup ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-checks/health.yml -vvv | tee ${LOGDIR}/05-pbs-healthcheck-`date +%F`.logs &
```

