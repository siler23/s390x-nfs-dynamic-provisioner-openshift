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

3. Set OpenShift username variable for login

    ```
    export openshift_username=your_openshift_username
    ```

4. Test logging into registry

    a. Run the following command to test logging in:

        echo "$(oc whoami --show-token)" | podman login --username ${openshift_username} --password-stdin "${internal_registry}"

    b. If successful, move on to Set NFS Server and Path section
    
    c. If you fail due to not having a valid token please login to openshift again via:

        oc login 

    d. If you fail due to the following error:

        x509: certificate signed by unknown authority

      move to the Adding Image Registry Certificate section

    e. If you fail due to something else, have fun debugging that one my friend (Tip: First make sure all the relevant variables are set)  

#### Adding Image Registry Certificate

1. Run the following command to grab the certificate for your image registry route:

    ```
    openssl s_client -showcerts -servername "${internal_registry}" -connect "${internal_registry}:443" </dev/null 2>/dev/null | openssl x509 > ca.crt
    ```

2. Make a directory for your image registry cert 

    ```
    sudo mkdir -p "/etc/containers/certs.d/${internal_registry}"
    ```

3. Copy your cert to your new directory

    ```
    sudo mv ca.crt /etc/containers/certs.d/${internal_registry}/ca.crt
    ```

4. Test Logging in again and you should be successful

    ```
    echo "$(oc whoami --show-token)" | podman login --username ${openshift_username} --password-stdin "${internal_registry}"
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
oc delete project nfs-client-provisioner
oc delete -f nfs-config-files-clusterwide/
rm -rf nfs-config-files*
```
