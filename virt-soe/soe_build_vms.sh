#!/bin/bash
# -*- mode: sh; -*-

TOOLDIR="/data-ssd/data/development/src/github/public/tools"
#TOOLDIR="/usr/local/bin"

var_playbook_connect="/etc/ansible/playbooks/connect-host.yml"       #${var_playbook_connect}
var_playbook_soe="/etc/ansible/playbooks/soe.yml"    	             #${var_playbook_soe}
vault="--vault-password-file ~/.ansible_vault_password"

#vmnames="centos7 fedora ubuntu_server temp"
#vm_fq_names="centos7.soe.vorpal fedora.soe.vorpal ubuntu_server.soe.vorpal temp.soe.vorpal"
#
#or:
#
vmnames="temp"
vm_fq_names="temp.soe.vorpal"

#Run sequence to setup vm:
echo
echo "Current VM status: ${vmnames}"
function jj-soe-status-vms () {
    ${TOOLDIR}/virt_soe/soe_create_vms.sh --domain soe --vms "${vmnames}" "status" $@
}
jj-soe-status-vms             #"${vmnames}" "status"

echo "Booting VMs: ${vmnames}"
function jj-soe-start-vms () {
    ${TOOLDIR}/virt_soe/soe_create_vms.sh --domain soe --vms "${vmnames}" "start" $@
}
jj-soe-start-vms              #"${vmnames}" "start"

echo "Waiting for VMs to boot:"
sleep 5

echo "Connecting vis ssh key: ${vm_fq_names}"
function jj-ansible-connect-play () {
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=all facts_on=no' ${var_playbook_connect} ${vault} --tags=connect-new-host --limit "${vm_fq_names}" $@
}
jj-ansible-connect-play        #"${vm_fq_names}"

echo "Installing Ansible requirements: ${vm_fq_names}"
function jj-ansible-connect-requirements () {
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=all facts_on=no' ${var_playbook_connect} ${vault} --tags=ansible_requirements --limit "${vm_fq_names}" $@
}
jj-ansible-connect-requirements #"${vm_fq_names}"

echo "Installing the SOE: ${vm_fq_names}"
function jj-ansible-soe-play-vms () {
    ansible-playbook -i /etc/ansible/hosts --extra-vars 'hostgroups=soe' ${var_playbook_soe} ${vault} --limit "${vm_fq_names}" $@
}
jj-ansible-soe-play-vms         #"${vm_fq_names}"

echo "Shutting down: ${vmnames}"
function jj-soe-shutdown-vms () {
    ${TOOLDIR}/virt_soe/soe_create_vms.sh --domain soe --vms "${vmnames}" "shutdown" $@
}
jj-soe-shutdown-vms             #"${vmnames}"

#Available operations:
#create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset
