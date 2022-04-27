# Simplified NFS Server Setup Steps

## Setup

1. Install the nfs-server package for your Linux distribution.

	1. On RHEL, run this command:
		```
		sudo yum install nfs-utils rpcbind
		```

	2. On Ubuntu, run this command:
		```
		sudo apt update && sudo apt install nfs-kernel-server
		```

	3. On SLES, run this command:
		```
		zypper -n install nfs-kernel-server
		```

2. Export a directory of the nfs-server (backed by file storage) to the worker nodes of the cluster by adding them to the `/etc/exports` file on the nfs-server linux instance. Then, load the directory.

	1. Create the directory if it doesn't already exist

		```
		sudo mkdir -p /srv/nfs/
		```

	2. Give ownership of dir to nobody

		```
		sudo chown -R nobody:nobody /srv/nfs
		```


	3. Export the directory


		```
		echo "<export_directory> <client_node_hostname_or_ip>(rw,fsid=0,insecure,no_subtree_check,async)" | sudo tee -a /etc/exports
		```

		*Add the client hostname or IP for each of the worker nodes. You can use a wildcard with hostnames such as kubernetes-worker* (if that was the hostname of each of your workers within your network) or an IP subnet mask (for example, 192.168.10/24).*

		Example Output For Hostname:

		```
		/srv/nfs worker-*.atsocpd3.dmz(rw,fsid=0,insecure,no_subtree_check,async)
		```

		Example Output For IP:

		```
		/srv/nfs 192.1.1.1(rw,fsid=0,insecure,no_subtree_check,async) 192.1.1.2(rw,fsid=0,insecure,no_subtree_check,async) 192.1.1.3(rw,fsid=0,insecure,no_subtree_check,async) 192.1.1.4(rw,fsid=0,insecure,no_subtree_check,async) 192.1.1.5(rw,fsid=0,insecure,no_subtree_check,async) 192.1.1.6(rw,fsid=0,insecure,no_subtree_check,async)
		```

3. Start the NFS server:

	1. On RHEL, run these commands:
		```
		sudo systemctl enable rpcbind
		sudo systemctl enable nfs-server
		sudo systemctl enable rpcbind
		sudo systemctl start nfs-server
		```
	
	2. On Ubuntu, run this command:
		```
		sudo systemctl start nfs-kernel-server.service
		```

	3. On SLES, run these commands:
		```
		sudo systemctl enable nfsserver
		sudo systemctl start nfsserver
		```

4. If nfs server was already started update nfs configuration with:

	```
	sudo exportfs -ra
	```

5. See newly created mount

	```
	showmount --exports
	```

	Example Output:

	```
	Export list for ocpd3bn1.atsocpd3.dmz:
	/srv/nfs worker-*.atsocpd3.dmz
	```

## Troubleshooting

**Note: If a firewall is running you will need to open necessary ports for rpcs for your given firewall for connections to be successful. (If firewall is blocking connection, you will get an error message like `Output: mount.nfs: No route to host`**

Tip: You can get rpc ports with the following

```
rpcinfo -p | uniq --skip-fields=2
```

Example Output:

```
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100024    1   udp  34599  status
    100024    1   tcp  50361  status
    100005    1   udp  20048  mountd
    100005    1   tcp  20048  mountd
    100005    2   udp  20048  mountd
    100005    2   tcp  20048  mountd
    100005    3   udp  20048  mountd
    100005    3   tcp  20048  mountd
    100003    3   tcp   2049  nfs
    100227    3   tcp   2049  nfs_acl
    100021    1   udp  48114  nlockmgr
    100021    1   tcp  36651  nlockmgr
```