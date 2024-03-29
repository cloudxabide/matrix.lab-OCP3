# Monitoring, Metrics, Logging

Status:   In-progress
Purpose:  Provide a quick guide to reviewing the monitoring tools/functions with OpenShift 3
          Highlight(s) of the services and endpoints for the different components  
Notes:   
It is worth explaining (and hopefully easy to visualize in this example), there are essentially 2 points of Ingress to my cluster.  
* master-api:8443 (in this case, using ocp3-console.linuxrevolution.com)  
* infra-routers:443 (in my case using *.ocp3-mwn.linuxrevolution.com)  

Now - the "Web Console" and API will utilize the "master" endpoint:  ocp3-console.linuxrevolution.com:8443  
All of the other services will utilze the "infra-routers" endpoint:  cluster-console.ocp3-mwn.linuxrevolution.com (as an example)

You can review the complete environment and architecture in the [README.md](../README.md) for this repo.

## Endpoints
Here are a list of endpoints (URLs) for my lab environment

### OCP3 URLs
https://ocp3-console.linuxrevolution.com:8443/console/  
https://cluster-console.ocp3-mwn.linuxrevolution.com/  
https://logging.ocp3-mwn.linuxrevolution.com/app/kibana  
https://hawkular.ocp3-mwn.linuxrevolution.com  (Endpoint Only - no User WebUI)

### Monitoring
NOTE:  These URLs are derived using the "openshift_master_default_subdomain" (provided in your inventory)  
https://prometheus-k8s-openshift-monitoring.ocp3-mwn.linuxrevolution.com/  
https://grafana-openshift-monitoring.ocp3-mwn.linuxrevolution.com  
https://alertmanager-main-openshift-monitoring.ocp3-mwn.linuxrevolution.com  
https://registry-console-default.ocp3-mwn.linuxrevolution.com/registry  
https://docker-registry-default.ocp3-mwn.linuxrevolution.com/ (Endpoint Only - no User WebUI)

## Review the UIs
Browse to https://ocp3-console.linuxrevolution.com:8443/console/ and login  
You will notice that this is very much project/namespace and application focused.  It lists the Projects which you have visiblity to, and a button to create a new project.  Additionally, the Catalog for deploying new applications.

Towards the top, you will see "Service Catalog" (the default value), click on it and select "Cluster Console"  
From there you can select
* Home   
  * Status | Search | Events  
* Workloads   
  * Pods | Deployments | Deployment Configs | Stateful Sets | Secrets | Config Maps  
  * Cronjobs | Jobs | Daemon Sets | Replica Sets | Replication Controllers | HPAs  
* Networking   
  * Services | Routes | Ingress | Network Policies  
* Storage  
  * Persistent Volumes | Persistent Volume Claims | Storage Classes
* Builds  
  * Build Configs | Builds | Image Streams
* Monitoring   
  * Metrics | Alerts | Dashboards   
* Administration   
  * Projects | Namespaces | Nodes | Service Accounts | Roles | Role Bindings | Resource Quotas | CRDs

### Monitoring | Metrics  
Destination:  Prometheus   
An example:  provide "sum(sort_desc(rate(container_cpu_usage_seconds_total{id="/"}[5m])))" for a query, then click "Execute", then "Graph"

### Monitoring | Dashboards  
Destination:  Grafana  
An example:  


