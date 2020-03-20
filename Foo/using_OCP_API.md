# Using API

```
HOSTNAME=rh7-ocp3-mst.matrix.lab
CERTIFICATE=${HOSTNAME}.pem
ENDPOINT=${HOSTNAME}:8443
OCPUSERNAME=ocpadmin
OCPPASSWORD=Passw0rd
```

## Login to the API
```
echo | openssl s_client -connect ${ENDPOINT}  -servername $HOSTNAME | sed -n /BEGIN/,/END/p > $CERTIFICATE
oc login --certificate-authority=$CERTIFICATE --username=$OCPUSERNAME --password=$OCPPASSWORD --server=${ENDPOINT}
```

## Access the API
```
TOKEN=`oc whoami -t`
echo | curl -k \
    -X POST \
    -d @- \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    https://${ENDPOINT}/apis/ 

```

## Notes
You need to escalate privs for the user to access (portions of) the API
```
oadm policy add-cluster-role-to-user cluster-admin ocpadmin
```

https://$ENDPOINT/apis/rbac.authorization.k8s.io/v1beta1/rolebindings <<'EOF'

