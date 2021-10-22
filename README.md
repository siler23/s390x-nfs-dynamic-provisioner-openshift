# openshift-nfs-provisioner
This repository contains bash scripts to automate the deployment of the dynamic nfs provisioner on OpenShift Container Platform 4.x using either external images or the OpenShift internal image registry.


## Table of Contents
* [Using this GitHub repository](#using-this-github-repository)
  - [Get the Code](#get-the-code)
  - [Pulling Updates](#pulling-updates)
  - [Prerequisites](#Prerequisites)
* [Running the Automation](#running-the-automation)
  - [Configuration](#configuration)
    * [Using Internal Image Registry if you don't have internet access](#using-internal-image-registry-if-you-don't-have-internet-access)
    * [Set NFS Server and Path](#set-nfs-server-and-path)
  - [Launching Script](#launching-script)
* [Cleanup](#cleanup)
  
## Using this GitHub repository

:octocat:

### Get the code

Using ssh:
```
git clone git@github.com:siler23/s390x-nfs-dynamic-provisioner-openshift.git
```

Using https:
```
git clone https://github.com/siler23/s390x-nfs-dynamic-provisioner-openshift.git
```

Download Link:

https://github.com/siler23/s390x-nfs-dynamic-provisioner-openshift/archive/master.zip

### Pulling updates

Get updates to this repo from within the repo directory with:

```
git pull
```

### Prerequisites

1. Login to OpenShift 4.x Cluster with `cluster-admin` access
    ```
    oc login
    ```

2. Have nfs server setup and add OpenShift nodes to exports list (`/etc/exports/`).

## Running the Automation

### Configuration

#### Using Internal Image Registry if you don't have internet access

**Outside cluster w/ routes**

1. Get created route:

    ```
    oc get route -n openshift-image-registry image-registry -o jsonpath='{.spec.host}' && echo
    ```

    Example Output: 
    ```
    image-registry-openshift-image-registry.apps.awesome.dmz
    ```

2. Set internal registry variable to use service

    ```
    export internal_registry=${internal_registry:-"image-registry-openshift-image-registry.apps.awesome.dmz"}
    ```

*NOTE: If route not exposed:*

```
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

**Inside cluster w/ service**

    
Set internal_registry variable to use service
    
```
export internal_registry=${internal_registry:-"image-registry.openshift-image-registry.svc:5000"}
```

#### Set NFS Server and Path
    
1. Set hostname/IP Address for NFS Server

    ```
    export nfs_server=${nfs_server:-"192.2.2.2"}
    ```

2. Set Path to exported directory on NFS Server (from server's point of view)

    ```
    export nfs_path=${nfs_path:-"/srv/nfs"}
    ```

### Launching Script

a. Variables Pre-set in configuration files:

```
./NFS_Client_Setup.sh
```

b. Set Variables as part of run:

```
nfs_server=192.2.2.2 nfs_path=/srv/nfs internal_registry=image-registry-openshift-image-registry.apps.awesome.dmz ./NFS_Client_Setup.sh
```

## Cleanup

Delete project, clusterwide resources and saved files

```
oc delete project nfs-client-dynamic-provisioner
oc delete -f nfs-config-files-clusterwide/
rm -rf nfs-config-files*
```
