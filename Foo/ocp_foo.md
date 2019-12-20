# OCP Foo

## OCS Troubleshooting

So - if/when using converged-but-independent Gluster nodes, I seem to have to do the following:
```
ansible all --list-hosts -i ~/ocp-${OCP_VERSION}*.yml 
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/prerequisites.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/openshift-glusterfs/config.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/deploy_cluster.yml
```


# CHECK DNS FROM ENTRIES IN PLAYBOOK
```

for HOSTNAME in `egrep 'openshift_m.*hostname' ~/matrix.lab/Files/ocp-3.11-multiple_master_native_ha-ocs-converged.yml | awk -F\= '{ print $2 }'`; do nslookup $HOSTNAME | grep ^Name ; done

for HOST in mst mst01 mst02 mst03; do echo "$HOST.matrix.lab"; dig +short rh7-ocp3-${HOST}.matrix.lab; echo; done
for HOSTNAME in `egrep 'openshift_m.*hostname' ~/matrix.lab/Files/ocp-3.11-multiple_master_native_ha-ocs-converged.yml | awk -F\= '{ print $2 }'`; do echo "$HOSTNAME"; dig +short $HOSTNAME; echo; done
dig +short test.$(egrep ^openshift_master_default_subdomain ~/matrix.lab/Files/ocp-3.11-multiple_master_native_ha-ocs-converged.yml | awk -F\= '{ print $2 }') 


```

Dig in to this further:
```
 oc --config=/etc/origin/master/admin.kubeconfig --namespace=glusterfs exec glusterfs-storage-8xm2l -- gluster volume heal vol_0ccc1014f4e2871e25589a5b4459da09 info
```
### Update HTPASSWD
```
for HOST in `grep mst0 ~/matrix.lab/Files/etc_hosts | awk '{ print $2 }'`; do ssh -t $HOST "sudo  htpasswd -b /etc/origin/master/htpasswd morpheus Passw0rd "; done
```

### OCP Health Check 
- From the bastion
```
ansible-playbook -i ~/ocp-${OCP_VERSION}-multiple_master_native_ha.yml playbooks/openshift-checks/health.yml
### Managing Cluster Permissions
# once the master is up-and-running, ssh to it
oadm policy add-cluster-role-to-user cluster-admin ocadmin
oc get nodes -owide
oc get all --all-namespaces
for PROJ in `oc get projects | grep -v "NAME" | awk '{ print $1 }'`; do echo -e "#################\n$PROJ"; oc get pods -n $PROJ; done
```

### References
https://github.com/gluster/glusterfs-kubernetes-openshift


## Default Projects
NAME DISPLAY
NAME STATUS
app-storage Active
default Active
infra-storage Active
kube-public Active
kube-service-catalog Active
kube-system Active
management-infra Active
openshift Active
openshift-ansible-service-broker Active
openshift-console Active
openshift-infra Active
openshift-logging Active
openshift-metrics-server Active
openshift-monitoring Active
openshift-node Active
openshift-sdn Active
openshift-template-service-broker Active
openshift-web-console Active

### MANUAL RETRY/REINSTALL
```
# https://docs.openshift.com/container-platform/3.11/install/running_install.html#advanced-retrying-installation
COUNTER=1
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-checks/pre-install.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node/bootstrap.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-etcd/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-nfs/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-loadbalancer/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
 &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-master/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-master/additional_config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node/join.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-glusterfs/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-hosted/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-monitoring/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-web-console/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-console/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/metrics-server/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-monitor-availability/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-service-catalog/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-management/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-descheduler/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node-problem-detector/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-autoheal/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) &
nohup ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/olm/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; $((COUNTER+1)); COUNTER=$((COUNTER+1)) &

