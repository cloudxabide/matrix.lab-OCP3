# Monitoring, Metrics, Logging

Quick highlight(s) of the services and endpoints for the different components

It is worth noting (and hopefully easy to visualize in this example), there are essentially 2 points of Ingress to my cluster.  
master-api:8443 (in this case, using .linuxrevolution.com)  
infra-routers:443 (in my case using *.ocp3-mwn.linuxrevolution.com)  

Now - the "Web Console" and API will utilize the "master" endpoint:  ocp3-console.linuxrevolution.com:8443  
All of the other services will utilze the "infra-routers" endpoint:  cluster-console.ocp3-mwn.linuxrevolution.com (as an example)


## Endpoints

### OCP3 URLs
https://ocp3-console.linuxrevolution.com:8443/console/  
https://cluster-console.ocp3-mwn.linuxrevolution.com/  
https://logging.ocp3-mwn.linuxrevolution.com/app/kibana  
https://hawkular.ocp3-mwn.linuxrevolution.com  (Endpoint Only - no User WebUI)

### Monitoring
NOTE:  These URLs are based on the "openshift_master_default_subdomain"  
https://prometheus-k8s-openshift-monitoring.ocp3-mwn.linuxrevolution.com/  
https://grafana-openshift-monitoring.ocp3-mwn.linuxrevolution.com  
https://alertmanager-main-openshift-monitoring.ocp3-mwn.linuxrevolution.com  
https://registry-console-default.ocp3-mwn.linuxrevolution.com/registry  
https://docker-registry-default.ocp3-mwn.linuxrevolution.com/ (Endpoint Only - no User WebUI)

## Review
Browse to https://ocp3-console.linuxrevolution.com:8443/console/ and login  
You will notice that this is very much project/namespace and application focused.  

