# Cluster Health Checks


root@master 
```
for NODE in ` oc get nodes | awk '{ print $1 }' | egrep -v '^NAME'`; do oc adm top node $NODE; echo; done

for NODE in ` oc get nodes | awk '{ print $1 }' | egrep -v '^NAME'`; do echo "$NODE"; oc describe node $NODE | awk '/Allocated resources/,/EOF/'; echo; done
```

root@bastion
``` 
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo df -h /var/lib/docker"; echo ; done
```
