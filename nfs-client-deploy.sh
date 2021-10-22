#!/usr/bin/env bash

set -Eeo pipefail

DeploymentCreationFail() {
    echo "${NAME} Deployment Failed"
    exit 1
}

CheckDeployFail() {
  echo "Error in Deployment Becoming Available"
  exit 1
}

trap DeploymentCreationFail ERR
set -x

cat << EOF > "nfs-config-files/${NAME}.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "${NAME}"
  labels:
    app: "${NAME}"
spec:
  replicas: ${replicaCount}
  strategy:
    type: "Recreate"
  selector:
    matchLabels:
      app: "${NAME}"
  template:
    metadata:
      labels:
        app: "${NAME}"
    spec:
      serviceAccountName: "${serviceAccountName}"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: "beta.kubernetes.io/arch"
                operator: In
                values:
                - "${arch}"
      priorityClassName: "${priorityClass}"
      containers:
        - name: "nfs-provisioner"
          image: "${nfs_image_repository}:${nfs_image_tag}"
          imagePullPolicy: "${nfs_pullPolicy}"
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: "${provisionerName}"
            - name: NFS_SERVER
              value: "${nfs_server}"
            - name: NFS_PATH
              value: "${nfs_path}"
          resources:
            requests:
              cpu: ${NFS_CPU_REQUEST}
              memory: ${NFS_MEMORY_REQUEST}
            limits:
              cpu: ${NFS_CPU_LIMIT}
              memory: ${NFS_MEMORY_LIMIT}
      volumes:
        - name: nfs-client-root
          nfs:
            server: "${nfs_server}" 
            path: "${nfs_path}" 
EOF

oc apply -f "nfs-config-files/${NAME}.yaml"

set +x

trap CheckDeployFail ERR
SECONDS=0
echo "Checking ${NAME} deployment in namespace: ${NAMESPACE}"

while (( $SECONDS < 200 ));
do 
  DEPLOY_NAME="${NAME}"
  TOTAL_PODS=$(oc get deploy --no-headers -n "${NAMESPACE}" "${NAME}" | awk '{print $2}' | awk '{print substr($0,length,1)}')
  IS_READY=$(oc get deploy --no-headers -n "${NAMESPACE}" "${NAME}" | awk '{print $2}')
  DEPLOY_STATUS="${IS_READY} Replicas Available"
  if [ "${IS_READY}" == "${TOTAL_PODS}/${TOTAL_PODS}" ]
  then
    break;
  fi
  echo "Waiting for deployment ${DEPLOY_NAME} to become available. Status = ${DEPLOY_STATUS}"
  sleep 3
  if [ $SECONDS -ge 200 ]
  then
    echo "Timed out waiting for deployment ${DEPLOY_NAME} to become available"
    exit 1
  fi
done