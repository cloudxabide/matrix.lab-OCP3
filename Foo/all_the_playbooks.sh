#!/bin/bash
# for FILE in `grep failed=1 * | awk -F: '{ print $1 }' | sort -u`; do echo "$FILE"; grep "plays in" $FILE; echo;  done
BASE="${HOME}/ocp-3.11-1212"
INVENTORY="${BASE}.yml"
LOGDIR="`date +%s`/"; mkdir ~/$LOGDIR
PLAYBOOKS="${PLAYBOOKS}"

COUNTER=1
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-checks/pre-install.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-checks_pre-install-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node/bootstrap.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-node_bootstrap-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-etcd/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-etcd-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-nfs/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-nfs-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-loadbalancer/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-loadbalancer-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-master/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-master-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-master/additional_config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-master_additional_config-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node/join.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-node_join-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-glusterfs/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-glusterfs_config-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-hosted/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-hosted-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-monitoring/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-monitoring-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-web-console/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-web-console-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-console/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-console-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-metrics/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-metrics-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}metrics-server/config.yml -vvv | tee ${LOGDIR}${COUNTER}-metrics-server-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-logging/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-logging-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-monitor-availability/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-monitor-availability-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-service-catalog/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-service-catalog-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-management/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-management-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-descheduler/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-descheduler-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node-problem-detector/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-node-problem-detector-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-autoheal/config.yml -vvv | tee ${LOGDIR}${COUNTER}-openshift-autoheal-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}olm/config.yml -vvv | tee ${LOGDIR}${COUNTER}-olm-`date +%F`.logs; $((COUNTER+1)); COUNTER=$((COUNTER+1)) 
