#!/usr/bin/env bash

set -Eeo pipefail

StorageClassCreateFail() {
    echo "Creation of storage class ${StorageClass} failed"
    exit 1
}

priorityClassCreateFail() {
    echo "Creation of Priority Class ${priorityClass} failed"
    exit 1
}

trap StorageClassCreateFail ERR

set -x
cat << EOF > "nfs-config-files-clusterwide/storageclass-${StorageClass}.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  labels:
    app: "${NAME}"
  name: "${StorageClass}"
  annotations:
    storageclass.kubernetes.io/is-default-class: "${defaultClass}"
provisioner: "${provisionerName}"
allowVolumeExpansion: true
reclaimPolicy: "${reclaimPolicy}"
parameters:
  archiveOnDelete: "false"
EOF

oc apply -f "nfs-config-files-clusterwide/storageclass-${StorageClass}.yaml"

set +x

trap priorityClassCreateFail ERR
set -x
cat << EOF > "nfs-config-files-clusterwide/priorityclass-${priorityClass}.yaml"
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  labels:
    app: "${NAME}"
  name: "${priorityClass}" 
value: ${priorityValue} 
globalDefault: false 
description: "This priority class should be used for dynamic storage provisioning pods only."
EOF

oc apply -f "nfs-config-files-clusterwide/priorityclass-${priorityClass}.yaml"
