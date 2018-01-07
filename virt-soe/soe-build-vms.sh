#!/bin/bash
# -*- mode: sh; -*-
# soe_build_vms.sh - script to sequence some ops using:
#    soe_create_vms.sh to: maniupulate libvirt vms
#    several ansible playbooks to connect & install soe on hosts 

#soe-vm-control.sh operates on a group of vms defined from a libvirt template:
#  available operations: create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset
soe_vm_control_script="/data-ssd/data/development/src/github/virt-tools/virt-soe/soe-vm-control.sh"

#ansible hosts/vault/playbook config:
var_playbook_connect="/etc/ansible/playbooks/connect-host.yml"       #${var_playbook_connect}
var_playbook_soe="/etc/ansible/playbooks/soe.yml"    	             #${var_playbook_soe}
vault="--vault-password-file ~/.ansible_vault_password"              #${vault}
hostsfile="-i /etc/ansible/hosts"                                    #${hostsfile} 

domain="soe"   #vm domain to use when creating vms, also used for hostgroup in ansible commands

#vms to operate on:
#def_vm_names="centos7 fedora ubuntu ubuntu_server temp foo bar"
#def_vm_fq_names="centos7.soe.vorpal fedora.soe.vorpal ubuntu ubuntu_server.soe.vorpal temp.soe.vorpal foo.soe.vorpal bar.soe.vorpal"
#or:
#def_vm_names="centos7 fedora ubuntu_server temp"
#def_vm_fq_names="centos7.soe.vorpal fedora.soe.vorpal ubuntu_server.soe.vorpal temp.soe.vorpal"
#or:
#def_vm_names="centos7 temp"
#def_vm_fq_names="centos7.soe.vorpal temp.soe.vorpal"
#or:
def_vm_names="temp"
def_vm_fq_names="temp.soe.vorpal"

function soe-set-vm_names () {
    export vm_names="${def_vm_names}"
    export vm_fq_names="${def_vm_fq_names}"
}
#when not set here, vm_names and vm_fq_names are taken from environment:
soe-set-vm_names  

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
function ansible-play           () { ansible-playbook ${vault} ${hostsfile} --extra-vars "hostgroups=${domain}" "$@" ; }
function ansible-play-facts-off () { ansible-playbook ${vault} ${hostsfile} --extra-vars "hostgroups=${domain} facts_on=no" "$@" ; }

#main playbook commmands:
function ansible-connect        () { ansible-play-facts-off ${var_playbook_connect} --tags=connect-new-host       "$@" ; }
function ansible-requirements   () { ansible-play-facts-off ${var_playbook_connect} --tags=ansible_requirements   "$@" ; }
function ansible-soe            () { ansible-play           ${var_playbook_soe}     --extra-vars 'hostgroups=soe' "$@" ; }

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
    echo "Waiting:    VMs: ${vm_names}"   #; sleep ${BOOTDELAY}
    set -- ${vm_names}
    no_of_vms=$#
    vm-test-boot
    up=$?
    while [[ ${up} -lt ${no_of_vms} ]]  ; do 
	sleep 1
	vm-test-boot
	up=$?
    done
    sleep 5   #qemu guest agent comes up fast, so, wait another 5 seconds for ssh
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

#set-x-on
########################################Start invoking commands here:
msg_start
#soe-vm-control-vms "status" --debug
#soe-vm-control     "status" --vms "${vm_names}"
#virsh list --all

sequence-full
#sequence-partial

msg_finished
########################################Finish here.
