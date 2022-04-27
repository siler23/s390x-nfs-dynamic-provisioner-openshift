# Simplified NFS Server Setup Steps

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

	```
	echo "<export_directory> <client_node_hostname_or_ip>(rw,fsid=0,insecure,no_subtree_check,async)" | sudo tee -a /etc/exports
	```

	*Add the client hostname or IP for each of the worker nodes. You can use a wildcard with hostnames such as kubernetes-worker* (if that was the hostname of each of your workers within your network) or an IP subnet mask (for example, 192.168.10/24).*

	Example `/etc/exports`:

	```
	/srv/nfs/blockchain/ocp 192.1.1.1(rw,insecure,no_subtree_check,sync,no_root_squash) 192.1.1.2(rw,insecure,no_subtree_check,sync,no_root_squash) 192.1.1.3(rw,insecure,no_subtree_check,sync,no_root_squash) 192.1.1.4(rw,insecure,no_subtree_check,sync,no_root_squash) 192.1.1.5(rw,insecure,no_subtree_check,sync,no_root_squash) 192.1.1.6(rw,insecure,no_subtree_check,sync,no_root_squash)
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