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
