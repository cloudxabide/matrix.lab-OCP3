
# This should remove all the storage/gluster references from your inventory
cp ocp-3.11-1112.yml ocp-3.11-1112-noGluster.yml

sed -i -e '/glusterfs_zone/ s/^#*/#/' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^\[gluster/#\[gluster/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^glusterfs/#glusterfs/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^openshift_hosted/#openshift_hosted/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^openshift_logging/#openshift_logging/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^openshift_storage/#openshift_storage/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^openshift_metrics/#openshift_metrics/g' ocp-3.11-1112-noGluster.yml
sed -i -e 's/^openshift_cluster_monitoring/#openshift_cluster_monitoring/g' ocp-3.11-1112-noGluster.yml

sdiff ocp-3.11-1112.yml ocp-3.11-1112-noGluster.yml | grep \| > sdiff-1112.yml
