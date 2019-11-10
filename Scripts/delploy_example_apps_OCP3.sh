
MYPROJ="hexgl"
oc new-project $MYPROJ
oc new-app php:5.6~https://github.com/cloudxabide/HexGL.git
# Create a secure route
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.ocp3-mwn.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -


At some point you will be able to browse to:  
https://hexgl.ocp3-mwn.linuxrevolution.com/
