
## Update Cluster Permissions and Roles


### Update the User(s) login credentials
```
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd morpheus Passw0rd"; done
```

### Elevate "ocpadmin" user to Cluster Admin
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

## Fix Prometheus
### Update Prometheus DC to reduce memory requirements
create endpoints and redeploy the logging pods after modifying the memory requirement  
oc edit dc -n openshift-logging
% s/16Gi/2Gi/g

### Metrics Storage
Again, not sure why this is not ALL handled by the Ansible playbooks

You need to figure out the pod name for "glusterblock-registry-provisioner-dc"
```
oc get pods --all-namespaces | grep provisioner
```

```
echo "apiVersion: v1
kind: Endpoints
metadata:
  annotations:
    control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"glusterblock-registry-provisioner-dc-1-gdpsx_fac4f0fb-2912-11ea-ac75-0a580a830203","leaseDurationSeconds":15,"acquireTime":"2019-12-28T01:40:08Z","renewTime":"2019-12-28T04:48:59Z","leaderTransitions":0}'
  name: gluster.org-glusterblock-infra-storage
  namespace: openshift-infra
subsets:
- addresses:
  - ip: 10.10.10.175
  - ip: 10.10.10.176
  - ip: 10.10.10.177
  ports:
  - port: 1
    protocol: TCP" | oc create -f -
```

Next, create the PV "metrics-1"
```

echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: metrics-1
  labels:
    metrics-infra: hawkular-cassandra
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 12Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: metrics-1
  persistentVolumeReclaimPolicy: Retain" | oc create -f -
```

Then, create the PVC "metrics-cassandra-1"
```
oc delete pvc/metrics-cassandra-1 -n openshift-infra

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{},"labels":{"metrics-infra":"hawkular-cassandra"},"name":"metrics-cassandra-1","namespace":"openshift-infra"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"12Gi"}}}}
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
      storage: 12Gi
  storageClassName: glusterfs-registry-block
  volumeName: metrics-1" | oc create -f -
```



## Update Storage 
### Create Endpoints (infra-storage)

oc delete endpoint gluster.org-glusterblock-infra-storage -n infra-storage

echo "apiVersion: v1
kind: Endpoints
metadata:
  annotations:
    control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"glusterblock-registry-provisioner-dc-1-gdpsx_fac4f0fb-2912-11ea-ac75-0a580a830203","leaseDurationSeconds":15,"acquireTime":"2019-12-28T01:40:08Z","renewTime":"2019-12-28T04:48:59Z","leaderTransitions":0}'
  name: gluster.org-glusterblock-infra-storage
  namespace: infra-storage
subsets:
- addresses:
  - ip: 10.10.10.191
  - ip: 10.10.10.192
  - ip: 10.10.10.193
  ports:
  - port: 1

