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

## Setting up your NFS Server

You need to set up an nfs mount point and export it to all OpenShift nodes you want to be able to access the storage. For more information on setting up nfs (if you don't have experience with this), see [Simplified NFS Server Setup Steps](NFS_server_setup.md)

## Running the Automation

### Configuration

#### Using Internal Image Registry (required if you don't have internet access)

##### Setup Image Registry and backing Storage using NFS (if not already setup)

If you want to use NFS for your internal image registry you can set it up with the following instructions (if you haven't already). *Note: If not NFS, you will at least want some kind of shareable backing storage if you are using the internal image registry at all for your cluster.*

1. Set hostname/IP Address for NFS Server

    ```
    export nfs_server="192.2.2.2"
    ```

2. Set path to exported directory for image-registry on NFS Server (from server's point of view) (directory should have 777 permissions)

    ```
    export nfs_registry_path="/srv/nfs/image-registry"
    ```


3. Create PV (Persistent Volume using your NFS server) for your OpenShift Image Registry

	```
    oc create -f - <<EOF
    apiVersion: v1
    kind: PersistentVolume
    metadata:
        name: image-registry
    spec:
        storageClassName: ""
        accessModes:
        - ReadWriteMany
        capacity:
            storage: 100Gi
        claimRef:
            namespace: openshift-image-registry
            name: image-registry
        nfs:
            path: "${nfs_registry_path}"
            server: "${nfs_server}"
        persistentVolumeReclaimPolicy: Recycle
    EOF
    ```

4. Create PVC (Persistent Volume Claim) for your OpenShift Image Registry

    ```
    oc create -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
        name: image-registry
        namespace: openshift-image-registry
    spec:
        storageClassName: ""
        accessModes:
        - ReadWriteMany
        resources:
            requests:
                storage: 100Gi
        volumeName: "image-registry"
    EOF
    ```

5. Make sure the pvc has bound properly

	```
    oc get pvc image-registry -n openshift-image-registry
    ```

    Example Output:

    ```
    NAME             STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    image-registry   Bound    image-registry   100Gi      RWX                           42s
    ```

6. Edit Image Registry config to use the newly created persistent volume claim

	```
	oc patch configs.imageregistry.operator.openshift.io cluster --type='json' -p='[{"op": "remove", "path": "/spec/storage" },{"op": "add", "path": "/spec/storage", "value": {"pvc":{"claim": "image-registry"}}}]'
	```

    Example Output:

    ```
    config.imageregistry.operator.openshift.io/cluster patched
    ```

7. Check Management State and Set Image Registry to Managed (if it's currently removed)

    1. Check management state (to see if removed)

        ```
        oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}' && echo
        ```

        Example Output:

        ```
        Removed
        ```

    2. If removed change to Managed

        ```
        oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
        ```

        Example Output:

        ```
        config.imageregistry.operator.openshift.io/cluster patched
        ```

8. Image Registry should become available

    1. Check Image Registry is up

        ```
        oc get deploy image-registry -n openshift-image-registry
        ```

        Example Output (after waiting a minute or so for deployment to become available):
        ```
        NAME             READY   UP-TO-DATE   AVAILABLE   AGE
        image-registry   1/1     1            1           44s
        ```

##### Access internal image registry and configuring script to use it
1. Get created route:

    a. Run the following command to get the route:

      ```
      oc get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}' && echo
      ```

      Example Output: 
      ```
      default-route-openshift-image-registry.apps.awesome.dmz
      ```

    b. If successful, move on to step 2 (setting the internal registry to use service)
    
    c. **If "default-route" not found**, patch the image registry config and then run the above `get route` command again*

      ```
      oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
      ```

      ```
      oc get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}' && echo
      ```

      Example Output: 
      ```
      default-route-openshift-image-registry.apps.awesome.dmz
      ```


2. Set internal registry variable to use service (remember to use your output instead of the example output for this)

    ```
    export internal_registry="image-registry-openshift-image-registry.apps.awesome.dmz"
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

##### Adding Image Registry Certificate

Note (ONLY if you are using podman machine such as on Mac or Windows instead of Podman on Linux) you can ssh into your Podman machine first and then use the following instructions (you can omit machine name for the default podman machine) with:

```
podman machine ssh machine_name
```


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

### Launching Script
#### Set NFS Server and Path
    
1. Set hostname/IP Address for NFS Server

    ```
    export nfs_server=${nfs_server:-"192.2.2.2"}
    ```

2. Set Path to exported directory on NFS Server (from server's point of view)

    ```
    export nfs_path="/srv/nfs"
    ```

#### Set Additional Variables (if desired) and Run Script

a. Variables Pre-set in configuration files:

```
./NFS_Client_Setup.sh
```

b. Set Variables as part of run:

```
nfs_server=192.2.2.2 nfs_path=/srv/nfs ./NFS_Client_Setup.sh
```

## Cleanup

Delete project, clusterwide resources and saved files

```
oc delete project nfs-client-provisioner
oc delete -f nfs-config-files-clusterwide/
rm -rf nfs-config-files*
```
