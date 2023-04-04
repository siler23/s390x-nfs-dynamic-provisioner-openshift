#!/usr/bin/env bash

set -Eeo pipefail

function TeamBanner(){
printf '
 ____   ___            ___ ____________ __   __    _    _____ __________ 
|  _ \\ / _ \\    /\\    / _ \\\\  ___)  ___)  \\ /  | _| |_ |  ___)  _ \\  ___)
| |_) ) |_| |  /  \\  | |_| |\\ \\   \\ \\  |   v   |/     \\| |_  | |_) ) \\   
|  _ (|  _  | / /\\ \\ |  _  | > >   > > | |\\_/| ( (| |) )  _) |  __/ > >  
| |_) ) | | |/ /__\\ \\| | | |/ /__ / /__| |   | |\\_   _/| |___| |   / /__ 
|____/|_| |_/________\\_| |_/_____)_____)_|   |_|  |_|  |_____)_|  /_____)
'
}

function CelebrationTime(){
printf '
@@@  @@@  @@@@@@@@   @@@@@@   
@@@@ @@@  @@@@@@@@  @@@@@@@   
@@!@!@@@  @@!       !@@       
!@!!@!@!  !@!       !@!       
@!@ !!@!  @!!!:!    !!@@!!    
!@!  !!!  !!!!!:     !!@!!!   
!!:  !!!  !!:            !:!  
:!:  !:!  :!:           !:!   
 ::   ::   ::       :::: ::   
::    :    :        :: : :    
                              
                                                      
 @@@@@@@  @@@       @@@  @@@@@@@@  @@@  @@@  @@@@@@@  
@@@@@@@@  @@@       @@@  @@@@@@@@  @@@@ @@@  @@@@@@@  
!@@       @@!       @@!  @@!       @@!@!@@@    @@!    
!@!       !@!       !@!  !@!       !@!!@!@!    !@!    
!@!       @!!       !!@  @!!!:!    @!@ !!@!    @!!    
!!!       !!!       !!!  !!!!!:    !@!  !!!    !!!    
:!!       !!:       !!:  !!:       !!:  !!!    !!:    
:!:        :!:      :!:  :!:       :!:  !:!    :!:    
 ::: :::   :: ::::   ::   :: ::::   ::   ::     ::    
 :: :: :  : :: : :  :    : :: ::   ::    :      :     
                                                      
                                                 
@@@@@@@   @@@@@@@@   @@@@@@   @@@@@@@   @@@ @@@  
@@@@@@@@  @@@@@@@@  @@@@@@@@  @@@@@@@@  @@@ @@@  
@@!  @@@  @@!       @@!  @@@  @@!  @@@  @@! !@@  
!@!  @!@  !@!       !@!  @!@  !@!  @!@  !@! @!!  
@!@!!@!   @!!!:!    @!@!@!@!  @!@  !@!   !@!@!   
!!@!@!    !!!!!:    !!!@!!!!  !@!  !!!    @!!!   
!!: :!!   !!:       !!:  !!!  !!:  !!!    !!:    
:!:  !:!  :!:       :!:  !:!  :!:  !:!    :!:    
::   :::   :: ::::  ::   :::   :::: ::     ::    
 :   : :  : :: ::    :   : :  :: :  :      :   
'
}

ProjectCreationFail() {
    echo "Project Creation Failed!!!"
    exit 1
}

ImageLoadFail() {
    echo "Image Load Failed!!!"
    exit 1
}

RBACCreationFail() {
    echo "RBAC Creation script failed"
    exit 1
}

StorageClassCreationFail() {
    echo "Storage Class Creation script failed"
    exit 1
}

NFSClientCreationFail() {
    echo "NFS Client Creation script failed"
    exit 1
}

NFSTestFail() {
    echo "Testing NFS script failed"
    exit 1
}

FinishFail() {
    echo "CAN DISREGARD ... Error calculating finish time and printing finish banner"
    exit 1
}
# Begin script by taking start time and printing team banner messsage
start_time=$(date +%s)
TeamBanner
# Save PROJECT_DIR to use throughout script
export PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Get environment variables from NFS_VARS.env
source "${PROJECT_DIR}/NFS_VARS.env"
export serviceAccountName=${serviceAccountName:-"${NAME}"}
export provisionerName=${provisionerName:-"nfs.io/${NAME}"}

export PROJECT_CHECK=$(oc projects | grep -o ${NAMESPACE})

# Throw error if PROXY_CHECK returns a value 
if [ -n "${PROJECT_CHECK}" ]; then
	echo -e "\nError: You can't create this project!!!"
    exit 1
fi

# Throw error if nfs_server not set by user
if [ -z "${nfs_server}" ]; then
	echo -e "\nError: NFS Server is not set !!! Please enter it manually with the following usage pattern. \n"
    echo -e "Usage:\n\tnfs_server=<server_ip> nfs_path=<path_to_nfs_export_on_server> ./NFS_Client_Setup.sh"
    exit 1
fi

# Throw error if nfs_path not set by user
if [ -z "${nfs_path}" ]; then
	echo -e "\nError: NFS Path is not set !!! Please enter it manually with the following usage pattern. \n"
    echo -e "Usage:\n\tnfs_server=<server_ip> nfs_path=<path_to_nfs_export_on_server> ./NFS_Client_Setup.sh"
    exit 1
fi

trap ProjectCreationFail ERR

oc adm new-project "${NAMESPACE}"

oc project "${NAMESPACE}"

if [ -n "${internal_registry}" ]; then
    trap ImageLoadFail ERR
    export nfs_image_repository="${internal_registry}/${NAMESPACE}/nfs-client-provisioner"
    export busybox_image_repository="${internal_registry}/${NAMESPACE}/busybox"
    ./upload-nfs-images.sh
    # Use local regitry address (service) for nodes in the cluster
    export nfs_image_repository="image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/nfs-client-provisioner"
    export busybox_image_repository="image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/busybox"
else
    export busybox_image_repository=${busybox_image_repository:-"quay.io/gmoney23/busybox"}
    export nfs_image_repository=${nfs_image_repository:-"quay.io/gmoney23/nfs-client-provisioner"}
fi

trap RBACCreationFail ERR

./nfs-rbac.sh

trap StorageClassCreationFail ERR

./nfs-class-deploy.sh

trap NFSClientCreationFail ERR

./nfs-client-deploy.sh

trap NFSTestFail ERR

./test-nfs.sh

trap FinishFail ERR
# Finish and give runtime as well as Celebratory Message
runtime=$(($(date +%s)-start_time))
CelebrationTime
echo
echo "It took $(( $runtime / 60 )) minutes and $(( $runtime % 60 )) seconds to setup the NFS Client Provisioner in project ${NAMESPACE}"
