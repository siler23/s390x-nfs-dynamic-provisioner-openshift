#!/usr/bin/env bash

set -Eeo pipefail
shopt -s expand_aliases
# Use podman if it exists

if command -v podman &> /dev/null
then
    echo "Using podman for Docker images"
    alias docker=podman
elif ! command -v docker &> /dev/null
then
    echo "You have neither Docker nor Podman installed on your system. Please install a container runtime to upload images with."
    exit 1
fi

echo "Logging into to OpenShift Internal Image Repository"
echo "$(oc whoami --show-token)" | docker login -u "$(oc whoami)" --password-stdin "${internal_registry}"

echo "Loading and pushing nfs provisioner image"
docker load -i "nfs-client-provisioner-${arch}-4.0.18.tar.gz"
docker tag gmoney23/nfs-client-provisioner-${arch}:4.0.18 "${nfs_image_repository}:${nfs_image_tag}"
docker push "${nfs_image_repository}:${nfs_image_tag}"

echo "Loading and pushing busybox test image"
docker load -i "busybox-${arch}-1.36.0.tar.gz"
docker tag quay.io/gmoney23/busybox-${arch}:1.36.0 "${busybox_image_repository}:${busybox_image_tag}"
docker push "${busybox_image_repository}:${busybox_image_tag}"
