# Deploy_Apps

## Setup your oc Client Environment
```
su - morpheus
PASSWORD=Passw0rd
echo | openssl s_client -connect rh7-ocp3-proxy.matrix.lab:8443 -servername rh7-ocp3-proxy.matrix.lab | sed -n /BEGIN/,/END/p > rh7-ocp3-proxy.matrix.lab.pem
oc login --certificate-authority=rh7-ocp3-proxy.matrix.lab.pem --username=`whoami` --password=$PASSWORD --server=rh7-ocp3-proxy.matrix.lab:8443
```

## HexGL
### Create Your Project and Deploy App (HexGL)
```
# HexGL is a HTML5 video game resembling WipeOut from back in the day (Hack the Planet!)
MYPROJ="hexgl"
oc new-project $MYPROJ
oc new-app php:5.6~https://github.com/cloudxabide/HexGL.git
# Create a secure route (hexgl.ocp3-mwn.linuxrevolution.com)
#echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.ocp3-mwn.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
# Or this route (hexgl.linuxrevolution.com)
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
```

At some point you will be able to browse to (depending on the route you enabled):  
https://hexgl.ocp3-mwn.linuxrevolution.com/
https://hexgl.linuxrevolution.com/

## Mattermost (this does not work at this time)
forked from - https://github.com/goern/mattermost-openshift.git   
As user:morpheus create the project "mattermost"
```
cd ${HOME}; git clone https://github.com/cloudxabide/mattermost-openshift.git; cd mattermost-openshift/
# Not sure why the DB is named incorrectly
sed -i -e 's/mattermost_test/mattermost/g' mattermost.yaml
# Need edge termination as I do not allow HTTP through my firewall
sed -i -e 's/targetPort: 8065/targetPort: 8065\n      tls:\n        termination: edge/g' mattermost.yaml
```

As user:morpheus create a new project
```
oc new-project mattermost
oc new-app postgresql-persistent -p POSTGRESQL_USER=mmuser \
                                 -p POSTGRESQL_PASSWORD=mostest \
                                 -p POSTGRESQL_DATABASE=mattermost \
                                 -p MEMORY_LIMIT=512Mi
```

As system:admin modify SCC (Do NOT do this in Prod) and add ImageStream
```
oc annotate namespace mattermost openshift.io/sa.scc.uid-range=1001/1001 --overwrite
oc adm policy add-scc-to-user anyuid system:serviceaccount:mattermost:mattermost
```

As user:morpheus create the mattermost app
```
oc create --filename mattermost.yaml
oc create serviceaccount mattermost
oc create secret generic mattermost-database --from-literal=user=mmuser --from-literal=password=mostest
oc secrets link mattermost mattermost-database

oc new-app --template=mattermost --labels=app=mattermost
oc tag mattermost:5.2-PCP mattermost:latest
oc expose service/mattermost --labels=app=mattermost
```

### Fix the Route (add edge termination)
As system:admin
```
oc edit route -n mattermost
  port:
    targetPort: 8065-tcp
>>>>>
  tls:
    termination: edge
<<<<<<
#Optional
  host: mattermost.linuxrevolution.com

```

### Enjoy
https://mattermost.linuxrevolution.com
Or the default URL
https://mattermost-mattermost.ocp3-mwn.linuxrevolution.com

### Cleanup
```
oc project mattermost
oc delete all --all
oc delete pvc postgresql -n mattermost
oc project hexgl
oc delete project mattermost
```

