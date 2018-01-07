#!/bin/bash
# -*- mode: sh; -*-

#soe_build_vms.sh
#
#Script to sequence some ops using:
#  soe_create_vms.sh to: maniupulate libvirt vms
#  several ansible playbooks to connect & install soe on hosts 
#
#This version doesn't rely on environment, you can tweak all the parameters within this script:

BOOTDELAY=30
SHUTDOWNDELAY=10

#location of soe_create_vms.sh:
soe_create_script="/data-ssd/data/development/src/github/virt-tools/virt-soe/soe_create_vms.sh"
alias jj-soe-create-vms="${soe_create_script} --domain soe --vms"
#Available operations:
#create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset

#ansible playbooks/vault config:
var_playbook_connect="/etc/ansible/playbooks/connect-host.yml"       #${var_playbook_connect}
var_playbook_soe="/etc/ansible/playbooks/soe.yml"    	             #${var_playbook_soe}
vault="--vault-password-file ~/.ansible_vault_password"
hostsfile="-i /etc/ansible/hosts"
facts_off="--extra-vars 'hostgroups=all facts_on=no'"

#vms to operate on:
#
#vmnames="centos7 fedora ubuntu_server temp"
#vm_fq_names="centos7.soe.vorpal fedora.soe.vorpal ubuntu_server.soe.vorpal temp.soe.vorpal"
#or:
vm_names="temp"
vm_fq_names="temp.soe.vorpal"

alias ansible-play="ansible-playbook                 ${vault} ${hostsfile}"
alias ansible-connect="ansible-playbook              ${vault} ${hostsfile} ${facts_off} ${var_playbook_connect} --tags=connect-new-host"
alias ansible-connect-requirements="ansible-playbook ${vault} ${hostsfile} ${facts_off} ${var_playbook_connect} --tags=ansible_requirements"
alias ansible-soe="ansible-playbook                  ${vault} ${hostsfile}              ${var_playbook_soe}     --extra-vars 'hostgroups=soe'"

function ansible-connect-vms () {
    ansible-connect --limit "${vm_fq_names}" $@
    #"shell sshpass -p {{ new_vm_password }}  ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{inventory_hostname}}"
}
function ansible-connect-vms-requirements () {
    #installs python2-dnf requirement for ansible, on el8+, fedora, and python/python-apt requirement for Debian :
    ansible-connect-requirements --limit "${vm_fq_names}" $@
}
function ansible-soe-play-vms () {     #run the main soe build playbook:
    ansible-soe --limit "${vm_fq_names}" $@
}
function ansible-soe-check-vms () {    #dry-run the main soe build playbook:
    ansible-soe --check --limit "${vm_fq_names}" $@
}

################################
#Run sequence to setup vm:

echo
echo "Current VM status: ${vm_names}"
soe-create-vms   "${vm_names}" status

echo "Defining: ${vm_names}"
soe-create-vms   "${vm_names}" define

echo "Booting VMs: ${vm_names}"
soe-create-vms   "${vm_names}" start

echo "Waiting for VMs to boot:"
sleep ${BOOTDELAY}

#operate on: "${vm_fq_names}"

echo "Connecting vis ssh key: ${vm_fq_names}"
ansible-connect --limit "${vm_fq_names}"
#or:
#ansible-connect-vms

echo "Installing Ansible requirements: ${vm_fq_names}"
ansible-connect-requirements --limit "${vm_fq_names}"
#or:
#ansible-connect-vms-requirements

echo "Running specific tags from the SOE: ${vm_fq_names}"
ansible-soe-play-vms --tags "f27-server,f27-runlevel" -vv

echo "Running SOE deploymemt tasks: ${vm_fq_names}"
#ansible-soe-play-vms

echo "Shutting down: ${vm_names}"
soe-create-vms   "${vm_names}" shutdown

echo "Waiting for VMs to shutdown:"
sleep ${SHUTDOWNDELAY}

echo "Status: ${vm_names}"
soe-create-vms   "${vm_names}" status

echo "Destroying: ${vm_names}"
soe-create-vms   "${vm_names}" destroy

echo "Undefining: ${vm_names}"
soe-create-vms   "${vm_names}" undefine









