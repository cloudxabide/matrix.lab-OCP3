#!/bin/bash
# for FILE in `grep failed=1 * | awk -F: '{ print $1 }' | sort -u`; do echo "$FILE"; grep "plays in" $FILE; echo;  done
BASE="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS-node_groups"
INVENTORY="${BASE}.yml"
COUNTER=1
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-checks/pre-install.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node/bootstrap.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-etcd/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-nfs/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-loadbalancer/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
 
# ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-master/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-master/additional_config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node/join.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
# ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-glusterfs/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-hosted/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-monitoring/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-web-console/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-console/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/metrics-server/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-monitor-availability/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-service-catalog/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-management/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-descheduler/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-node-problem-detector/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/openshift-autoheal/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; COUNTER=$((COUNTER+1)) 
ansible-playbook -i ${INVENTORY} /usr/share/ansible/openshift-ansible/playbooks/olm/config.yml -vvv | tee ocp_manual_install-${COUNTER}-`date +%F`.logs; $((COUNTER+1)); COUNTER=$((COUNTER+1)) 

