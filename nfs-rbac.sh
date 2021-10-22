#!/usr/bin/env bash

set -Eeo pipefail

SACreationFail() {
    echo "${serviceAccountName} Creation Failed"
    exit 1
}

RoleCreationFail() {
    echo "role-${NAME} Creation Failed"
    exit 1
}

RoleBindingCreationFail() {
    echo "rolebinding-${NAME} Creation Failed"
    exit 1
}

ClusterRoleCreationFail() {
    echo "clusterrole-${NAME} Creation Failed"
    exit 1
}

ClusterRoleBindingCreationFail() {
    echo "clusterrolebinding-${NAME} Creation Failed"
    exit 1
}

SCCCreationFail() {
    echo "securitycontextconstraints-${NAME} Creation Failed"
    exit 1
}

SCCAddFail() {
    echo "securitycontextconstraints ${NAME} could not be added to Service Account ${serviceAccountName}"
    exit 1
}

set -x
trap SACreationFail ERR
mkdir -p "nfs-config-files"
cat << EOF > "nfs-config-files/serviceaccount-${NAME}.yaml"
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app: "${NAME}"
  name: "${serviceAccountName}"
EOF

oc apply -f "nfs-config-files/serviceaccount-${NAME}.yaml"

set +x

trap RoleCreationFail ERR

set -x
cat << EOF > "nfs-config-files/role-${NAME}.yaml"
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    app: "${NAME}"
  name: "leader-locking-${NAME}"
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
EOF

oc apply -f "nfs-config-files/role-${NAME}.yaml"

set +x

trap RoleBindingCreationFail ERR

set -x
cat << EOF > "nfs-config-files/rolebinding-${NAME}.yaml"
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    app: "${NAME}"
  name: "leader-locking-${NAME}"
subjects:
  - kind: ServiceAccount
    name: "${serviceAccountName}"
    namespace: "${NAMESPACE}"
roleRef:
  kind: Role
  name: "leader-locking-${NAME}"
  apiGroup: rbac.authorization.k8s.io
EOF

oc apply -f "nfs-config-files/rolebinding-${NAME}.yaml"

set +x

trap ClusterRoleCreationFail ERR

set -x
mkdir -p "nfs-config-files-clusterwide"
cat << EOF > "nfs-config-files-clusterwide/clusterrole-${NAME}.yaml"
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    app: "${NAME}"
  name: "${NAME}-runner"
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
EOF

oc apply -f "nfs-config-files-clusterwide/clusterrole-${NAME}.yaml"

set +x

trap ClusterRoleBindingCreationFail ERR

set -x
cat << EOF > "nfs-config-files-clusterwide/clusterrolebinding-${NAME}.yaml"
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    app: "${NAME}"
  name: "run-${NAME}"
subjects:
  - kind: ServiceAccount
    name: "${serviceAccountName}"
    namespace: "${NAMESPACE}"
roleRef:
  kind: ClusterRole
  name: "${NAME}-runner"
  apiGroup: rbac.authorization.k8s.io
EOF

oc apply -f "nfs-config-files-clusterwide/clusterrolebinding-${NAME}.yaml"

set +x

trap SCCCreationFail ERR

set -x
cat << EOF > "nfs-config-files-clusterwide/securitycontextconstraints-${NAME}.yaml"
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: "${NAME}"
  labels:
    app: "${NAME}"
allowPrivilegedContainer: false
allowPrivilegeEscalation: false
requiredDropCapabilities:
  - ALL
volumes:
  - 'secret'
  - 'nfs'
allHostNetwork: false
allowHostIPC: false
allowHostPID: false
runAsUser:
  type: 'RunAsAny'
seLinuxContext:
  type: 'RunAsAny'
supplementalGroups:
  type: 'RunAsAny'
fsGroup:
  type: 'RunAsAny'
readOnlyRootFilesystem: false
EOF

oc apply -f "nfs-config-files-clusterwide/securitycontextconstraints-${NAME}.yaml"

set +x

trap SCCAddFail ERR

oc adm policy add-scc-to-user "${NAME}" --serviceaccount "${serviceAccountName}"