

## Setup your oc Client Environment
```
su - morpheus

echo | openssl s_client -connect rh7-ocp3-proxy.matrix.lab:8443 -servername rh7-ocp3-proxy.matrix.lab | sed -n /BEGIN/,/END/p > rh7-ocp3-proxy.matrix.lab.pem
oc login --certificate-authority=rh7-ocp3-proxy.matrix.lab.pem --username=`whoami` --password=Passw0rd --server=rh7-ocp3-proxy.matrix.lab:8443
```

## Create Your Project and Deploy App (HexGL)
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

