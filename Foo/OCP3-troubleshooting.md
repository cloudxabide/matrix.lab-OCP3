
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
