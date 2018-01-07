#!/bin/bash
# -*- mode: sh; -*-
# soe_build_vms.sh - script to sequence some ops using:
#    soe_create_vms.sh to: maniupulate libvirt vms
#    several ansible playbooks to connect & install soe on hosts 
#
# Can call this script like:
#    ~/src/github/virt-tools/virt-soe/soe-build.sh --vms "centos7 fedora"
# The soe-vm-control script is alao called like:
#    ~/src/github/virt-tools/virt-soe/soe-vm-control.sh status   --vms "centos7 fedora temp foo bar ubuntu ubuntu_server"
# If present, --vms "foo bar" must be the last parameter

#soe-vm-control.sh operates on a group of vms defined from a libvirt template:
#  available operations: create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset
TOOL_DIR="/data-ssd/data/development/src/github/ansible-soe"
soe_vm_control_script="${TOOL_DIR}/virt-soe/soe-vm-control.sh"

#ansible hosts/vault/playbook config:
var_playbook_connect="/etc/ansible/playbooks/connect-host.yml"       #${var_playbook_connect}
var_playbook_soe="/etc/ansible/playbooks/soe.yml"    	             #${var_playbook_soe}
vault="--vault-password-file ~/.ansible_vault_password"              #${vault}
hostsfile="-i /etc/ansible/hosts"                                    #${hostsfile} 
domain="soe.vorpal"     #vm "domain" to use when creating vms
hostgroup=${domain%.*}  #use leftmost part of domain for ansible hostgroup
SSHD_DELAY=15           #extra delay to wait for ssh.

#vms to operate on:
#def_vm_names="centos7 fedora ubuntu ubuntu_server temp foo bar"
#def_vm_names="centos7 fedora ubuntu_server temp"
#def_vm_names="centos7 temp"
def_vm_names="centos7"
vm_names=""

function soe-set-vm_names () {
    export vm_names="${def_vm_names}"
    vm_fq_names=""
    for i in ${vm_names} ; do 
	#echo "Adding ${i} to vm_fq_names=${vm_fq_names}"
	###vm_fq_names+="${i}.${domain}."
	vm_fq_names+="${i}.${domain} "
	#echo "vm_fq_names=${vm_fq_names}"
    done
    #vm_fq_names=${vm_fq_names%*.} #strip trailing ,
    vm_fq_names=${vm_fq_names%* } #strip trailing " "
    export vm_fq_names
}
function usage () {
    echo "Usage:"
    exit
}

function process_args () {
    #call like: process_args "$@"
    if [[ "$#" == "0" ]]; then
	echo "No arguments. Halp!"
	usage
    fi
    local ok=1
    while (( "$#" )); do
	case ${1} in          #switches for this shell script begin with '--'
            -h | help)        usage;;
            -d | --debug )    export debug=1; export DEBUG=echo ; echo -e "\nDebug mode on.";;
            --vms)            shift ; export def_vm_names="$@" ; soe-set-vm_names ; echo "VMs = ${vm_names}" ; shift $# ;; #shift to use up all args
            *)                ok=0 ; echo "Unrecognised option: ${1}" ;  usage ;;
	esac;
	shift
    done
    if [ $ok -eq 0 ] ; then echo "Halp. Something isn't right with the command arguments. Exiting." ; usage ; fi
    echo
}

function soe-vm-control () {
    #usage> soe-vm-control "operation" --vms "${vm_names}"
    operation=$1 ; shift ;
    #echo "${operation}:   $@"
    ${soe_vm_control_script} --domain "${domain}" "${operation}" "$@" 
}
function soe-vm-control-vms () {
    #usage> soe-vm-control "operation"
    operation=$1 ; shift ;
    #echo "VMs: ${vm_fq_names}"
    #echo "${operation}:   $@"
    ${soe_vm_control_script} --domain "${domain}" "${operation}" --vms "${vm_names}" "$@" 
}

#basic command without playbook, facts on/off:
function ansible-play           () { ansible-playbook ${vault} ${hostsfile} --extra-vars "hostgroups=${hostgroup}"             "$@" ; }
function ansible-play-facts-off () { ansible-playbook ${vault} ${hostsfile} --extra-vars "hostgroups=${hostgroup} facts_on=no" "$@" ; }

#main playbook commmands:
function ansible-connect        () { ansible-play-facts-off ${var_playbook_connect} --tags=connect-new-host                "$@" ; }
function ansible-requirements   () { ansible-play-facts-off ${var_playbook_connect} --tags=ansible_requirements            "$@" ; }
function ansible-soe            () { ansible-play           ${var_playbook_soe}     --extra-vars "hostgroups=${hostgroup}" "$@" ; }

#test status of vms:
function vm-test-boot () {
    vms_up=0
    for i in  ${vm_names} ; do 
	virsh qemu-agent-command "${domain}_${i}" '{"execute":"guest-ping"}' 2>/dev/null | grep -q "return"    ##good ping gives: {"return":{}}
	if [[ $? -eq 0 ]] ; then    #grep returns 0 on match
	    echo "${i} is Up."
	    vms_up+=1
	else
	    echo "${i} is not Up."
	fi
    done
    return $vms_up
}
function vm-wait-boot () {
    echo "Waiting:    VMs: ${vm_names}"
    set -- ${vm_names}
    no_of_vms=$#
    vm-test-boot
    up=$?
    while [[ ${up} -lt ${no_of_vms} ]]  ; do 
	sleep 1
	vm-test-boot
	up=$?
    done
    echo "Waiting ${SSHD_DELAY} seconds extra for sshd to come up."
    sleep ${SSHD_DELAY} #qemu guest agent comes up fast, so, wait 5 secs for ssh
}
function vm-test-up () {
    vms_up=0
    for i in  ${vm_names} ; do 
	virsh list --state-running --name | grep -q "$i"
	if [[ $? -eq 0 ]] ; then   #grep returns 0 on match
	    echo "${i} is running."
	    vms_up+=1
	else
	    echo "${i} is not running."
	fi
    done
    return $vms_up
}
function vm-wait-shutdown () {
    echo "Waiting:    VMs: ${vm_names}"
    vm-test-up
    up=$?
    while [[ ${up} -gt 0 ]]  ; do 
	sleep 1
	vm-test-up
	up=$?
    done
}

#misc:
function msg_start () {
    echo
    echo "Started"
    date +%H-%M-%S
    echo
}
function msg_finished () {
    echo
    echo "Finished:"
    date +%H-%M-%S
    echo
}

#testing:
function set-x-on () {
    set -x
}
function set-x-off () {
    set +x
}
function test-tags () {
    vm-ansible-run-soe --tags "f27-server,f27-runlevel" -vv
}
function test-vm-control () {
    soe-vm-control "status" --vms "${vm_names}"
}

#That's all we really need. Now we can define some groups of commands and then some sequences which use these groups:

function vm-boot () {
    soe-vm-control-vms "status"
    soe-vm-control-vms "define"
    soe-vm-control-vms "start"
}
function vm-shutdown () {
    soe-vm-control-vms "shutdown"
    vm-wait-shutdown
    #soe-vm-control-vms "destroy"  #should not be necessary
    soe-vm-control-vms "undefine"
}
function vm-undefine () {
    soe-vm-control-vms "destroy"
    soe-vm-control-vms "undefine"
}
function vm-ansible-setup () {
    echo "Connecting vis ssh key: ${vm_fq_names}"             ; ansible-connect      --limit "${vm_fq_names}"
    echo "Installing Ansible requirements: ${vm_fq_names}"    ; ansible-requirements --limit "${vm_fq_names}"
}
function vm-ansible-run-soe () {
    echo "Running SOE deploymemt tasks: ${vm_fq_names}"       ; ansible-soe          --limit "${vm_fq_names}" "$@"
}

#sequences:
function sequence-full () {
    echo "Running full sequence to: define, start, connect, install soe, shutdown, undefine:"
    vm-boot
    vm-wait-boot
    vm-ansible-setup 
    vm-ansible-run-soe
    vm-shutdown
}
function sequence-partial () {
    echo "Running ad-hoc sequence of commands:"   #comment or uncomment as desired:
    #soe-vm-control-vms "status"

    #vm-boot
    #or:
    #soe-vm-control-vms "undefine"
    #soe-vm-control-vms "define"
    #soe-vm-control-vms "start"

    #virsh list --all
    #vm-wait-boot

    #vm-ansible-setup 
    #vm-ansible-run-soe

    #vm-shutdown
    #or:
    #soe-vm-control-vms "shutdown"
    #vm-wait-shutdown
    #soe-vm-control-vms "destroy"
    #soe-vm-control-vms "undefine"
}
function sequence-test () {
    echo "Running test sequence of commands:"   #comment or uncomment as desired:
    #soe-vm-control-vms "reimage"   #replace with (small, sparse) blank disk image
    #soe-vm-control-vms "refresh"   #replace with image of freshly installed os
}
#set-x-on
########################################Start invoking commands here:
#when not set here, vm_names and vm_fq_names are taken from environment, or from $@:
soe-set-vm_names  
process_args $@    #mainly just process --vm-names "foo bar"
msg_start

#soe-vm-control-vms "status" --debug
#soe-vm-control     "status" --vms "${vm_names}"
#virsh list --all

sequence-full
#equence-partial
#sequence-test 

msg_finished
########################################Finish here.
