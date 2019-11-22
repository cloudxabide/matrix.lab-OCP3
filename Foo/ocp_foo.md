# OCP Foo

## OCS Troubleshooting

So - if/when using converged-but-independent Gluster nodes, I seem to have to do the following:
```
ansible all --list-hosts -i ~/ocp-${OCP_VERSION}*.yml 
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/prerequisites.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/openshift-glusterfs/config.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/deploy_cluster.yml
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
