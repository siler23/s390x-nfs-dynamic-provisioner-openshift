#!/usr/bin/env bash

set -Eeo pipefail

TestClaimCreationFail(){
    echo "test-claim-${NAME} Creation Failed"
    exit 1
}

TestPodCreationFail() {
    echo "test-pod-${NAME} Creation failed"
    exit 1
}

CheckTestFail() {
  echo "Error in Test Pod Finishing"
  exit 1
}

trap TestClaimCreationFail ERR
set -x
cat << EOF > "nfs-config-files/test-claim-${NAME}".yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: "test-claim-${NAME}"
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  storageClassName: "${StorageClass}"
  resources:
    requests:
      storage: 1Mi
EOF

oc apply -f "nfs-config-files/test-claim-${NAME}.yaml"

set +x

trap TestPodCreationFail ERR

set -x
cat << EOF > "nfs-config-files/test-pod-${NAME}".yaml
kind: Pod
apiVersion: v1
metadata:
  name: "test-pod-${NAME}"
  labels:
    app: "test-pod-${NAME}"
spec:
  containers:
  - name: busybox-test
    image: "${busybox_image_repository}:${busybox_image_tag}" 
    imagePullPolicy: "${busybox_pullPolicy}"
    command:
      - "/bin/sh"
    args:
      - "-c"
      - "touch /mnt/SUCCESS && exit 0 || exit 1"
    volumeMounts:
      - name: nfs-pvc
        mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: "test-claim-${NAME}"
EOF

oc apply -f "nfs-config-files/test-pod-${NAME}.yaml"

set +x

trap CheckTestFail ERR

SECONDS=0
echo "Checking test-pod completion in namespace: ${NAMESPACE}"

while (( $SECONDS < 200 ));
do 
  POD_NAME="test-pod-${NAME}"
  POD_STATUS=$(oc get pod --no-headers -n "${NAMESPACE}" "${POD_NAME}" | awk '{print $3}')
  TOTAL_PODS=$(oc get pod --no-headers -n "${NAMESPACE}" "${POD_NAME}" | awk '{print $2}' | awk '{print substr($0,length,1)}')
  IS_READY=$(oc get pod --no-headers -n "${NAMESPACE}" "${POD_NAME}" | awk '{print $2}')
  if [ "${POD_STATUS}" == "Completed" ]
  then
    break;
  fi
  echo "Waiting for test pod ${POD_NAME} to become available. Status = ${POD_STATUS}, Readiness = ${IS_READY}"
  sleep 3

  if [ $SECONDS -ge 200 ]
  then
    echo "Timed out waiting for test pod ${POD_NAME} to complete"
    exit 1
  fi
done
