#!/bin/bash
# -*- mode: sh; -*-

#script to sequence some ops using:
# soe_create_vms.sh to: maniupulate libvirt vms
# several ansible playbooks to connect & install soe on hosts 

#location of soe_create_vms.sh:
TOOLDIR="/data-ssd/data/development/src/github/virt-tools/virt-soe"
#TOOLDIR="/usr/local/bin"

#ansible playbooks/vault config:
var_playbook_connect="/etc/ansible/playbooks/connect-host.yml"       #${var_playbook_connect}
var_playbook_soe="/etc/ansible/playbooks/soe.yml"    	             #${var_playbook_soe}
vault="--vault-password-file ~/.ansible_vault_password"

#vms to operate on:
#
#vmnames="centos7 fedora ubuntu_server temp"
#vm_fq_names="centos7.soe.vorpal fedora.soe.vorpal ubuntu_server.soe.vorpal temp.soe.vorpal"
#
#or:
#
vmnames="temp"
vm_fq_names="temp.soe.vorpal"

#Available operations:
#create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset

function jj-soe-status-vms () {
    ${TOOLDIR}/soe_create_vms.sh --domain soe --vms "${vmnames}" "status" $@
}
function jj-soe-start-vms () {
    ${TOOLDIR}/soe_create_vms.sh --domain soe --vms "${vmnames}" "start" $@
}
function jj-ansible-connect-play () {
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=all facts_on=no' ${var_playbook_connect} ${vault} --tags=connect-new-host --limit "${vm_fq_names}" $@
    #"shell sshpass -p {{ new_vm_password }}  ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@{{inventory_hostname}}"
}
function jj-ansible-connect-requirements () {
    #installs python2-dnf requirement for ansible, on el8+, fedora, and python/python-apt requirement for Debian :
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=all facts_on=no' ${var_playbook_connect} ${vault} --tags=ansible_requirements --limit "${vm_fq_names}" $@
}
function jj-ansible-soe-play-vms () {
    #run the main soe build playbook:
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=soe' ${var_playbook_soe} ${vault} --limit "${vm_fq_names}" $@
}
function jj-soe-shutdown-vms () {
    ${TOOLDIR}/soe_create_vms.sh --domain soe --vms "${vmnames}" "shutdown" $@
}

################################
#Run sequence to setup vm:

echo
echo "Current VM status: ${vmnames}"
jj-soe-status-vms

echo "Booting VMs: ${vmnames}"
jj-soe-start-vms

echo "Waiting for VMs to boot:"
sleep 5

echo "Connecting vis ssh key: ${vm_fq_names}"
jj-ansible-connect-play

echo "Installing Ansible requirements: ${vm_fq_names}"
jj-ansible-connect-requirements

echo "Installing the SOE: ${vm_fq_names}"
jj-ansible-soe-play-vms

echo "Shutting down: ${vmnames}"
jj-soe-shutdown-vms

