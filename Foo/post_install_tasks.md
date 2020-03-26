# Post Install Tasks

## Update Haproxy 
Host: rh7-ocp3-proxy.matrix.lab
If you opt to use the LB managed/created by the OCP install for your Infra Nodes, review [../Foo/haproxy_update.txt](../Foo/haproxy_update.txt)

## Update the size of the Journal (syslog)
Host: rh7-ocp3-bst01.matrix.lab
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh -oConnectTimeout=3 $HOST "uname -n; sudo grep SystemMaxUse= /etc/systemd/journald.conf"; echo "#########################"; done
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh -oConnectTimeout=3 $HOST "uname -n; sudo sed -i -e 's/SystemMaxUse=8G/SystemMaxUse=2G/g' /etc/systemd/journald.conf"; sleep 2; echo "#########################"; done
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh -oConnectTimeout=3 -t -l root $HOST "uname -n; systemctl restart systemd-journald"; echo "#########################"; done
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh -oConnectTimeout=3 -t -l root $HOST "uname -n; journalctl --vacuum-time=1d "; echo "#########################"; done

## Update Cluster Permissions and Roles
### Update the User(s) login credentials
```
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd morpheus Passw0rd"; done
```

### Elevate "ocpadmin" user to Cluster Admin
Host: rh7-ocp3-mst01.matrix.lab
```
oadm policy add-cluster-role-to-user cluster-admin ocpadmin
```

## Update Storage 
### Update Endpoints (infra-storage)
```
oc edit endpoints gluster.org-glusterblock-infra-storage -n infra-storage

=========================
subsets:
- addresses:
  - ip: 10.10.10.191
  - ip: 10.10.10.192
  - ip: 10.10.10.193
  ports:
  - port: 1
    protocol: TCP
=========================
```

### Create Endpoints (app-storage)
```
oc edit endpoints gluster.org-glusterblock-app-storage -n app-storage
=========================
subsets:
- addresses:
  - ip: 10.10.10.196
  - ip: 10.10.10.197
  - ip: 10.10.10.198
  ports:
  - port: 1
    protocol: TCP
=========================
```

## Fix Prometheus Sizing (after running "all_the_playbooks.sh")
### Update Prometheus DC to reduce memory requirements
NOTE:  This is no longer *necessary*, I resolved this by updating the inventory file
create endpoints and redeploy the logging pods after modifying the memory requirement  
oc edit dc -n openshift-logging
% s/16Gi/2Gi/g
for DC in `oc get dc | grep "logging-es" | awk '{ print $1 }'`; do oc rollout latest $DC; done

## NOTE:  
The following is not necessary if things went as planned, but I am keeping it in here.

## Update Storage (openshift-infra)
### Metrics Storage (
Again, not sure why this is not ALL handled by the Ansible playbooks

You need to figure out the pod name for "glusterblock-registry-provisioner-dc"
```
oc get pods --all-namespaces | grep provisioner
```

Next, create the PV "metrics-cassandra-1"
```
echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: metrics-cassandra-1
  labels:
    metrics-infra: hawkular-cassandra
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: metrics-cassandra-1
  persistentVolumeReclaimPolicy: Retain" | oc create -f -
```

```
echo "apiVersion: v1
kind: Endpoints
metadata:
  annotations:
  name: gluster.org-glusterblock-infra-storage
  namespace: openshift-logging
subsets:
- addresses:
  - ip: 10.10.10.191
  - ip: 10.10.10.192
  - ip: 10.10.10.193
  ports:
  - port: 1
    protocol: TCP" | oc create -f -
```

```
echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: es-logging-app-0
  labels:
    logging-infra: support
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 13Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: es-logging-app-0 
  persistentVolumeReclaimPolicy: Retain" | oc create -f -

echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: es-logging-app-1
  labels:
    logging-infra: support
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 13Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: es-logging-app-1
  persistentVolumeReclaimPolicy: Retain" | oc create -f -

echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: es-logging-app-2
  labels:
    logging-infra: support
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 13Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: es-logging-app-2
  persistentVolumeReclaimPolicy: Retain" | oc create -f -

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    logging-infra: support
  name: es-logging-app-0
  namespace: openshift-logging
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 13Gi
  storageClassName: glusterfs-registry-block
  volumeName: es-logging-app-0" | oc create -f -

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    logging-infra: support
  name: es-logging-app-1
  namespace: openshift-logging
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 13Gi
  storageClassName: glusterfs-registry-block
  volumeName: es-logging-app-1" | oc create -f -

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    logging-infra: support
  name: es-logging-app-2
  namespace: openshift-logging
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 13Gi
  storageClassName: glusterfs-registry-block
  volumeName: es-logging-app-2" | oc create -f -

```

## NOTES - Likely not actually needed....

Create the PVC 
```
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{},"labels":{"metrics-infra":"hawkular-cassandra"},"name":"metrics-cassandra-1","namespace":"openshift-infra"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}
  creationTimestamp: "2020-02-07T03:54:18Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    metrics-infra: hawkular-cassandra
  name: metrics-cassandra-1
  namespace: openshift-infra
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi" | oc create -f - 
```

ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}/openshift-metrics/config.yml -e openshift_metrics_install_metrics=False
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}/openshift-metrics/config.yml -e openshift_metrics_install_metrics=True




Then, create the PVC "metrics-cassandra-1"
```
oc delete pvc/metrics-cassandra-1 -n openshift-infra

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{},"labels":{"metrics-infra":"hawkular-cassandra"},"name":"metrics-cassandra-1","namespace":"openshift-infra"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    metrics-infra: hawkular-cassandra
  name: metrics-cassandra-1
  namespace: openshift-infra
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: glusterfs-registry-block
  volumeName: metrics-cassandra-1" | oc create -f -
```

