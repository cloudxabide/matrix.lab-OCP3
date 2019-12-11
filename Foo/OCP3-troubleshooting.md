
Using curl to analyze certs *might* not be a good strategy
```
curl -k https://10.10.10.172:8443/healthz/ready
```


/var/log/messages
search for: Linux version 3


```
etcd_ctl=2 etcdctl  --cert-file=/etc/origin/master/master.etcd-client.crt  \
          --key-file /etc/origin/master/master.etcd-client.key \
          --ca-file /etc/origin/master/master.etcd-ca.crt \
          --endpoints="https://rh7-ocp3-mst01.matrix.lab*:2379,\
          https://rh7-ocp3-mst02.matrix.lab*:2379,\
          https://rh7-ocp3-mst03.matrix.lab*:2379"\
          cluster-health
```

# 
```
/usr/local/bin/master-logs etcd etcd
```

```
[root@rh7-ocp3-mst01 ~]# oc get events --all-namespaces | head -1 
NAMESPACE        LAST SEEN   FIRST SEEN   COUNT     NAME                                                            KIND        SUBOBJECT                      TYPE      REASON                    SOURCE                                     MESSAGE
[root@rh7-ocp3-mst01 ~]# oc get events --all-namespaces | grep Err 
openshift-node   16m         16m          1         sync.15dd80ab3a989d8f                                           DaemonSet                                  Warning   FailedCreate              daemonset-controller                       Error creating: Pod "sync-82nxx" is invalid: spec.containers[0].image: Invalid value: " ": must not have leading or trailing whitespace
openshift-sdn    16m         16m          1         sdn.15dd80b01820f290                                            DaemonSet                                  Warning   FailedCreate              daemonset-controller                       Error creating: Pod "sdn-l25fx" is invalid: spec.containers[0].image: Invalid value: " ": must not have leading or trailing whitespace
openshift-sdn    16m         16m          1         ovs.15dd80b04d8a1693                                            DaemonSet                                  Warning   FailedCreate              daemonset-controller                       Error creating: Pod "ovs-w5ns2" is invalid: spec.containers[0].image: Invalid value: " ": must not have leading or trailing whitespace
```

https://docs.openshift.com/container-platform/3.11/install/running_install.html#advanced-retrying-installation

https://docs.openshift.com/container-platform/3.11/admin_guide/manage_nodes.html#marking-nodes-as-unschedulable-or-schedulable
[root@rh7-ocp3-mst01 ~]# oc adm manage-node rh7-ocp3-app01.matrix.lab rh7-ocp3-app02.matrix.lab rh7-ocp3-app03.matrix.lab --schedulable=true



```
echo | openssl s_client -connect rh7-ocp3-mst.matrix.lab:8443 -servername rh7-ocp3-mst.matrix.lab | sed -n /BEGIN/,/END/p > rh7-ocp3-mst.matrix.lab.pem
oc login --certificate-authority=rh7-ocp3-mst.matrix.lab.pem --user morpheus --server=rh7-ocp3-mst.matrix.lab:8443
oc login --certificate-authority=rh7-ocp3-mst.matrix.lab.pem --username=morpheus --password=Passw0rd4769 --server=rh7-ocp3-mst.matrix.lab:8443
```



