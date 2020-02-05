

```
oc project infra-storage
oc get pods 
oc rsh glusterfs-registry-9xsrb
gluster peer status
gluster volume info
```

Create a PV 
```
echo "apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: pv-es-logging-app-1
spec:
  storageClassName: glusterfs-registry-block
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 9Gi
  glusterfs:
    endpoints: gluster.org-glusterblock-infra-storage
    path: pv-es-logging-app-1
  persistentVolumeReclaimPolicy: Retain" | oc create -f -

```

Create a PVC
```
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    volume.beta.kubernetes.io/storage-provisioner: gluster.org/glusterblock-infra-storage
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
      storage: 9Gi
  storageClassName: glusterfs-registry-block
  volumeName: pv-es-logging-app-0" | oc create -f -

```

## Metrics Storage
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

# Restart the pod
```
oc delete pod `oc get pod -n openshift-infra | grep ContainerCreating | awk '{ print $1 }'` -n openshift-infra
```
Create the endpoints (in the openshift-logging namespace)  
This is still a work in progress.  Ugh  


## Endpoints
For some reason I have found endpoints defined... with no endpoints???

add the following to the endpoint
```
oc edit endpoints <endpoint name>

subset:
- addresses:
  - ip: 10.10.10.191
  - ip: 10.10.10.192
  - ip: 10.10.10.193
  ports:
  - port: 1
    protocol: TCP
```

```
# oc edit endpoints gluster.org-glusterblock-app-storage -n app-storage

subsets:
- addresses:
  - ip: 10.10.10.196
  - ip: 10.10.10.197
  - ip: 10.10.10.198
  - ip: 10.10.10.199
  ports:
  - port: 1
    protocol: TCP
```

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
    protocol: TCP" | oc create -f -


## Haproxy Testing 
### Check Routes
- https://docs.openshift.com/container-platform/3.9/rest_api/oapi/v1.Route.html
```
ENDPOINT="rh7-ocp3-mst01.matrix.lab"
oc login -u ocpadmin -p Passw0rd --insecure-skip-tls-verify --server=https://$ENDPOINT:8443
TOKEN=`oc whoami -t`
curl -k -H "Authorization: Bearer $TOKEN" \
  -H 'Accept: application/json' \
  https://$ENDPOINT:8443/oapi/v1/route 

```
