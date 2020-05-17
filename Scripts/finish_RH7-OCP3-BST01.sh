#!/bin/bash
OCP_VERSION=3.11

case $OCP_VERSION in
  3.9)
    OCP_REPOS_MGMT='subscription-manager repos --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.9-rpms" --enable="rhel-7-fast-datapath-rpms"  --enable="rhel-7-server-ansible-2.4-rpms"'
  ;;
  *)
    OCP_REPOS_MGMT='subscription-manager repos --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.11-rpms" --enable="rhel-7-server-ansible-2.8-rpms"'
  ;;
esac

case $OCP_VERSION in
  3.9)
    DOCKER_VERSION="docker-1.13.1 "
    OPENSHIFT_UTILS="atomic-openshift-utils "
  ;;
  *)
    DOCKER_VERSION="docker "
    OPENSHIFT_UTILS="openshift-ansible "
  ;;
esac

echo "sudo yum -y install $OPENSHIFT_UTILS $DOCKER_VERSION"
sudo yum -y install $OPENSHIFT_UTILS 
sudo yum -y install atomic-openshift-clients
