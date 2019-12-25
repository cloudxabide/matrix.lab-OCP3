#!/bin/bash
# for FILE in `grep failed=1 * | awk -F: '{ print $1 }' | sort -u`; do echo "$FILE"; grep "plays in" $FILE; echo;  done
BASE="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS-node_groups"
INVENTORY="${BASE}.yml"
LOGDIR="`date +%s`/"; mkdir ~/$LOGDIR; cd ~/$LOGDIR
PLAYBOOKS="${PLAYBOOKS}"

COUNTER=
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-checks/pre-install.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node/bootstrap.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-etcd/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-nfs/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-loadbalancer/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-master/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-master/additional_config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node/join.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-glusterfs/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-hosted/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-monitoring/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-web-console/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-console/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-metrics/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}metrics-server/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-logging/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-monitor-availability/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-service-catalog/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-management/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-descheduler/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-node-problem-detector/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}openshift-autoheal/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} ${PLAYBOOKS}olm/config.yml -vvv | tee ${LOGDIR}ocp_manual_install-${COUNTER}-`date +%F`.logs; $((COUNTER+1)); COUNTER=$((COUNTER+1)) 
