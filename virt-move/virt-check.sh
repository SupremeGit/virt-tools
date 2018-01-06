#!/bin/sh
# virt-check.sh 
#
# Script to quickly work out which vm definitions have missing images.
# Can spit out a list of:
#   - vm xml definition files (for either good or bad vms)
#   - path to disk image file (either missing or found)
#
#Usage exanples:
#
#find bad vms:
# ./virt-check.sh --check_vms --bad
#/etc/libvirt/qemu/z_6Tb-ipa-rl2-01-sv-ipa.el6.xml
#/etc/libvirt/qemu/z_6Tb-ipa-rl2-01-ws-ipa.el6.xml
#
#find the images in those vms that are missing:
#./virt-check.sh --check_images --bad
#/mnt/6Tb/Shared-6tb/data/kvm/vm/ranlads2/ipa/rhel-guest-image-6.7-20160301.1.x86_64-ipa.qcow2
#/mnt/6Tb/Shared-6tb/data/kvm/vm/ranlads2/ipa/rhel6.7-ws-ipa.qcow2
#

VERSION="v1.0 11/12/2017" 
AUTHOR="John Sincock"

#set -x
DEBUG=
#DEBUG=echo

ok=0 ; debug=0 ; 
check_images=0 ; check_vms=0    #what to check
verbose=0 ; bad=0 ; good=0;     #what to report

usage () {
    echo
    echo "virt-check.sh --check_vms --check_images --good --bad"
    echo "  --check_vms       : report on vms"
    echo "  --check images    : report on image files"
    echo "  --good            : report good vms/found images"
    echo "  --bad             : report bad vms/missing images"
    echo "  --verbose         : extra guff making it clearer which vms are missing which files."
    exit
}

if [ "$#" == "0" ]; then
    echo "No arguments. Halp!"
    usage
fi

while (( "$#" )); do
    case ${1} in              #switches for this shell script begin with '--'
	-h | --help)          usage;;
	-d | --debug)         debug=1 ; DEBUG=echo ; echo -e "\nDebug mode on.";;
	-v | --verbose )      verbose=1; echo -e "\nVerbose mode on.";;
	--check_images)       ok=1; check_images=1;;
	--check_vms)          ok=1; check_vms=1;;
	--bad)                bad=1;;    #report badness
	--good)               good=1;;   #report goodness
	
	*)                    ok=0 ; echo "Unrecognised option." ;  usage ;;
    esac;
    shift
done

if [ $ok -eq 0 ] ; then
    echo "Halp. Something isn't right with the command arguments. Exiting." ; usage ;
    exit
fi

VIRT_DIR="/etc/libvirt/qemu"
#VIRT_DIR="/data-ssd/data/development/src/github/public/tools/virt/qemu"
#VIRT_DIR=.

#VM_DIR_SSD="/data-ssd/data/kvm/vm"
#VM_DIR_6TB="/mnt/6Tb-linux/data/kvm/vm"
#VM_DIR_6TB_LINUX="/mnt/6Tb/Shared-6tb/data/kvm/images"

function print_debug () {
    if [[ $debug -eq 1 ]] ; then echo "$1" ; fi
}
function print_verbose () {
    if [[ $verbose -eq 1 ]] ; then echo "$1" ; fi
}
function print_bad () {
    if [[ $bad -eq 1 ]] ; then echo "$1" ; fi
}
function print_good () {
    if [[ $good -eq 1 ]] ; then echo "$1" ; fi
}

check_image_file () {
    myfile="$1"
    if [[ -e "${myfile}" ]] ; then
	if [[ $check_images -eq 1 ]] ; then
	    print_verbose "Found disk image:"
	    print_good "${myfile}"
	fi
	returncode=1
    else
	if [[ $check_images -eq 1 ]] ; then
	    print_verbose "Missing disk image:"
	    print_bad "${myfile}"
	fi
	returncode=0
    fi
    return $returncode
}

function check_vm_file () {
    vm_config="$1"
    all_present=1
    print_verbose ""
    print_verbose "Checking image files in: ${vm_config}"
    SAVED_IFS="$IFS"
    IFS=$'\n'
    for i in `cat "${vm_config}" | grep "source file"` ; do
	filename=`echo $i | cut -f 2 -d "'"`   #ugly but works
	print_verbose "Checking image file: ${filename}"
	check_image_file "${filename}"
	exists=$?
	if [[ $exists -eq 0 ]] ; then all_present=0 ; fi
    done
    IFS=$SAVED_IFS

    if [[ $check_vms -eq 1 ]] ; then
	if [[ $all_present -eq 0 ]] ; then
	    print_verbose "VM is missing disk image(s):"
	    print_bad "${vm_config}"
	else
	    print_verbose "VM has all its disk image(s):"
	    print_good "${vm_config}"  
	fi
    fi    
    print_verbose ""
}

function check_configs () {
    for i in "${VIRT_DIR}"/*.xml ; do
	check_vm_file "$i"
    done
}

#########start here
print_verbose ""

check_configs

print_verbose ""


################################
#ll /mnt/6Tb-linux/data/kvm/vm/
#drwxr-xr-x 2 root root  86 Jul 25 01:43 ipa
#drwxr-xr-x 2 root root 220 Jul 25 00:49 ipa-pki-vagans
#drwxr-xr-x 2 root root 128 Nov 11 00:07 nutanix
#drwxr-xr-x 2 root root  34 Mar  7  2017 openindiana
#drwxr-xr-x 4 root root  47 Mar  8  2017 vmware
#drwxrwxrwx 2 qemu qemu 141 Jul 22 18:43 windows
#
#ll /mnt/6Tb/Shared-6tb/data/kvm/images/
#-rwxrwxrwx 1 root root 197008 Feb 27  2017 25G.qcow2
#drwxrwxrwx 1 root root      0 Mar  9  2017 hyper-v
#drwxrwxrwx 1 root root   4096 Jul 22 18:40 ipa
#drwxrwxrwx 1 root root   4096 Jul 25 00:49 ipa-pki-vagans
#drwxrwxrwx 1 root root      0 Jul 22 18:41 jss
#drwxrwxrwx 1 root root      0 Jul 23 08:28 lago
#drwxrwxrwx 1 root root      0 Jul 22 18:26 minix
#drwxrwxrwx 1 root root   4096 Nov 10 22:36 nutanix
#drwxrwxrwx 1 root root      0 Feb 26  2017 ovirt
#drwxrwxrwx 1 root root      0 May  8  2016 ranlads2
#drwxrwxrwx 1 root root      0 Jul 22 19:21 ranlads2-kvm
#drwxrwxrwx 1 root root      0 Jan 14  2017 ranlads2-old-i-think
#drwxrwxrwx 1 root root      0 May 12  2016 rhel
#drwxrwxrwx 1 root root      0 Mar  6  2017 rhev
#drwxrwxrwx 1 root root      0 Jul 22 18:45 vmware
#drwxrwxrwx 1 root root      0 Jan 14  2017 vmware-player-images
#drwxrwxrwx 1 root root      0 Jul 22 18:43 windows
#
#ll /data-ssd/data/kvm/vm/
#drwxr-xr-x 2 root root  39 Mar  9  2017 hyper-v
#drwxr-xr-x 2 root root 170 Nov 21 02:53 jss
#drwxrwxrwx 2 qemu jss    6 Feb 27  2017 lago
#drwxr-xr-x 2 root root  46 Jul 22 18:21 minix
#drwxr-xr-x 7 root root 261 Mar  6  2017 ovirt
#drwxrwxr-x 3 jss  root  21 Nov 13  2016 ranlads2
#drwxr-xr-x 8 root root 182 Mar  6  2017 rhev
#drwxr-xr-x 4 root root 115 Jul 24 04:45 vmware
#drwxr-xr-x 2 qemu qemu 136 Jul 26 08:28 win-server
