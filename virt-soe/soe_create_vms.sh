#!/bin/bash

#TEMPLATE_DIR=/etc/libvirt/z_templates
TEMPLATE_DIR=/data-ssd/data/development/src/github/public/tools/virt_soe/soe-vms
vmnames="centos fedora"
domain="soe"
#DEBUG=echo 

BALLS=Salty ; debug=0 ;  help=0 ; ok=1
usage () {
    echo
    echo "soe_create_vms.sh"
    echo 
    echo "Usage > soe_create_vms.sh --vms \"vm1 vm2 ...\" [operation]"
    echo
    echo "      -h | --help                     Lists this usage information."
    echo "      -d | --debug                    Echo the commands that will be executed."
    echo "      --vms  \"vm1 vm2\"                Space separated quoted list of vm names"
    echo "      --domain  \"soe\"                 Domain name."
    echo
    echo "Available VMs:"
    echo "               centos7           7.4"
    echo "               fedora26"
    echo "               fedora           27"
    echo "               rawhide"
    echo "               ubuntu           17.04 Desktop"
    echo "               ubuntu_server    17.04 Server"
    echo "               temp"
    echo "               foo"
    echo "               bar"
    echo
    echo "Operations:"
    echo "      status"
    echo
    echo "      create         Create and start."
    echo "      define         Create VM."
    echo "      undefine       Delete VM from libvirt (keeps disk image)."
    echo "      reimage        Overwrite the disk image with an empty one (default domain=soe)."
    echo "      refresh        Overwrite the disk image with a freshly installed one (default domain=soe)."
    echo
    echo "      start"
    echo "      destroy        Stop"
    echo "      save"
    echo "      restore"
    echo
    echo "      shutdown"
    echo "      reboot"
    echo "      reset"
    echo "      "
    echo "Todo:"
    echo "      suspend resume managedsave autostart-on autostart-off "  #suspend/resume=pause/unpause
    echo "      desc = set description"
    echo "      set-user-password domain user password [--encrypted]"
    echo
    exit
}
function process_args () {
    #call like: process_args "$@"
    if [[ "$#" == "0" ]]; then
	echo "No arguments. Halp!"
	usage
    fi

    while (( "$#" )); do
	case ${1} in          #switches for this shell script begin with '--'
            -h | help)        usage;;
            -d | --debug )    export debug=1; export DEBUG=echo ; echo -e "\nDebug mode on.";;
            status)           echo -e "Executing command: status." ; operation="domstate --reason";;

            create | define | undefine | reimage | refresh | start | destroy | save | restore | shutdown | reboot | reset )
                operation="${1}" ; echo -e "Executing operation: $1.";;
	    --vms)            ok=1 ; vmnames="$2"  ; echo "Operating on vms: ${vmnames}" ; shift ;;
	    --domain)         domain="$2"  ; echo "Operating on domain: ${domain}" ; shift ;;
            *)                ok=0 ; echo "Unrecognised option." ;  usage ;;
	esac;
	shift
    done
    
    if [ $ok -eq 0 ] ; then echo "Halp. Something isn't right with the command arguments. Exiting." ; usage ; fi
    echo
}

function check_operation () {
    op="$1"
    if [[ "domstate --reason start destroy save restore shutdown reboot reset" == *"${op}"* || "${op}" == "undefine" ]] ; then 
	echo "Valid normal operation: ${op}"
	return 1;
    else
	return 0
    fi
}

function check_xml_operation () {
    op="$1"
    if [[ "create define" == *"${op}"* ]] ; then 
	echo "Valid xml_file operation: ${op}"
	return 1;
    else
	return 0
    fi
}

function vm_op_all () {
    operation="$1"
    for i in ${vmnames} ; do 
	echo "${i}:"
	$DEBUG virsh ${operation} "${domain}_${i}"
    done
}
function vm_xml_op_all () {
    operation="$1"
    echo "${i}"
    for i in ${vmnames} ; do 
	$DEBUG virsh "${operation}" "${TEMPLATE_DIR}/${domain}-vms/{domain}_${i}.xml"
    done
}
function vm_reimage () {
    $DEBUG cp --sparse=always -v "/data-ssd/data/kvm/images/25G.qcow2" "/data-ssd/data/kvm/vm/${domain}/${1}.qcow2"
}
function vm_reimage_all () {
    for i in ${vmnames} ; do 
	vm_reimage "${i}"
    done
}
function vm_refresh () {
    mydomain="$1"
    myvmname="$2"
    $DEBUG cp --sparse=always -v "/mnt/6Tb/Shared-6tb/data/kvm/images/${mydomain}/${myvmname}-vm01.qcow2" "/data-ssd/data/kvm/vm/${mydomain}/${myvmname}.qcow2"
}
function vm_refresh_all () {
    for i in ${vmnames} ; do 
	#if [[ "${i}" == "rawhide"       ]] ; then vm_reset_rawhide       ; fi
	vm_refresh "${domain}" "${i}"
    done
}

###########################################################
#start here:

echo
process_args "$@"

#vm_all
if [[ $( check_operation "${operation}" ) ]] ; then 
    vm_op_all "${operation}"
elif [[ $( check_xml_operation "${operation}" ) ]] ; then 
    vm_xml_op_all "${operation}"
elif [[ "${operation}" == "reimage" ]] ; then 
    vm_reimage_all 
elif [[ "${operation}" == "freshen" ]] ; then 
    vm_refresh_all 
else 
    echo "Hmm. Unknown operation: ${operation}"
fi

echo