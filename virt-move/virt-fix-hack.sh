#!/bin/sh
# virt-fix-hack.sh 
#
# Nasty hack to use virt-move.pl to carefully fix my dodgy vm files with images that I've moved to new locations
#
#"virt-fix-hack.sh [ --move ]
#  --move    creates ${OLD_DIR} and moves old xml files there.
# 
# Uses virt-check.pl to examine vm xml files in current directory.
# And uses virt-move.pl to fix vms which reference disk images that I've moved to new locations.
# Fixed xml files will be created in ${FIXED_DIR}.
#

VERSION="v1.0 11/12/2017" 
AUTHOR="John Sincock"

#set -x
DEBUG=
#DEBUG=echo

VIRT_DIR="."
FIXED_DIR="./fixed"
OLD_DIR="./z_old"
mkdir -p "${FIXED_DIR}"

#TOOL_DIR="/data-ssd/data/development/src/github/public/tools/virt"
TOOL_DIR="/usr/local/bin"

verbose=0 ; debug=0 ; move=0 ;

usage () {
    echo
    echo  "virt-fix-hack.sh [ --move ]" 
    echo  "   --move    creates ${OLD_DIR} and moves old xml files there."
    echo 
    echo "Uses virt-check.pl to examine vm xml files in current directory."
    echo "And uses virt-move.pl to fix vms which reference disk images that I've moved to new locations."
    echo "Fixed xml files will be created in ${FIXED_DIR}."
    exit
}

#if [ "$#" == "0" ]; then
#    echo "No arguments. Halp!"
#    usage
#fi

while (( "$#" )); do
    case ${1} in              #switches for this shell script begin with '--'
	-h | --help)          usage;;
	-d | --debug)         debug=1; DEBUG=echo ; echo -e "\nDebug mode on.";;
	-v | --verbose )      verbose=1; echo -e "\nVerbose mode on.";;
	-m | --move)          move=1 ; echo -e "\nMoving original files into ${OLD_DIR}.\n" ; mkdir -p" ${OLD_DIR}" ;;
	*)                    ok=0 ; echo "Unrecognised option." ;  usage ;;
    esac;
    shift
done

function print_debug () {
    if [[ $debug -eq 1 ]] ; then echo "$1" ; fi
}
function print_verbose () {
    if [[ $verbose -eq 1 ]] ; then echo "$1" ; fi
}

function fix_vm () {
    vm_file="$1"
    my_old_path="$2"
    my_new_path="$3"
    VM_BASENAME=`basename "${vm_file}"`
    FIXED_FILENAME=${FIXED_DIR}/${VM_BASENAME}
    print_verbose "Fixing ${vm_file}."
    echo "Fixed file: ${FIXED_FILENAME}"

    if [[ $debug -eq 0 ]] ; then
	cat "${vm_file}" | "${TOOL_DIR}/virt-move.pl" "${my_old_path}" "${my_new_path}" > "${FIXED_FILENAME}"
    else
	echo "Fixing ${vm_file}: <${my_old_path}> -> <${my_new_path}> -> ${FIXED_FILENAME}"
    fi
    if [[ $move -eq 1 ]] ; then
	print_verbose "Moving old xml config ${vm_file} to ${OLD_DIR}" ;
	$DEBUG mkdir -p "${OLD_DIR}"
	$DEBUG mv "${vm_file}" "${OLD_DIR}/"
    fi
}

function fix_vms () {
    old_path="$1"
    new_path="$2"
    for bad_vm in `${TOOL_DIR}/virt-check.sh --check_vms --bad` ; do
	print_verbose "Checking bad VM <${bad_vm}> for bad path: <${old_path}>."
	if [[ `grep "${old_path}" "${bad_vm}"` ]] ; then   #if bad_vm has our bad path in it, then fix:
	    fix_vm "${bad_vm}" "${old_path}" "${new_path}"
	fi 
    done
}

function run-01 () {
    fix_vms "/data-ssd/data/kvm/iso/minix_"            "/mnt/6Tb/Shared-6tb/data/isos/minix/minix_" 
    fix_vms "/data-ssd/data/kvm/vm/ipa/"               "/mnt/6Tb-linux/data/kvm/vm/ipa/"
    fix_vms "/data-ssd/data/kvm/vm/openindiana/"       "/mnt/6Tb-linux/data/kvm/vm/openindiana/"
    
    #VMS on 6tb ntfs, these are crap i prolly wanna delete them after checking them:
    fix_vms "/data-ssd/data/kvm/vm/ranlads2/ipa/"      "/mnt/6Tb/Shared-6tb/data/kvm/vm/ranlads2/ipa/"
    fix_vms "/data-ssd/data/kvm/vm/ranlads2/nt4-ldap/" "/mnt/6Tb/Shared-6tb/data/kvm/vm/ranlads2/nt4-ldap/"
    fix_vms "/data-ssd/data/kvm/vm/ranlads2/nt4-tdb/"  "/mnt/6Tb/Shared-6tb/data/kvm/vm/ranlads2/nt4-tdb/"
}

function run-02 () {
    echo "Next run here:"
}


#cd "${VIRT_DIR}"
$DEBUG mkdir -p "${FIXED_DIR}"

##run-01  #done
run-02

echo
