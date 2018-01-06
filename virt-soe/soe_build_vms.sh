#!/bin/bash
# -*- mode: sh; -*-

#soe_build_vms.sh
#
#Script to sequence some ops using:
#  soe_create_vms.sh to: maniupulate libvirt vms
#  several ansible playbooks to connect & install soe on hosts 
#
#This version doesn't rely on environment, you can tweak all the parameters within this script:

#location of soe_create_vms.sh:
soe_create_script="/data-ssd/data/development/src/github/virt-tools/virt-soe/soe_create_vms.sh"
alias jj-soe-create-vms="${soe_create_script} --domain soe --vms"
#Available operations:
#create, define, undefine, define, reimage, refresh, start, destroy, save. restore, shutdown, reboot, reset

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
vm_names="temp"
vm_fq_names="temp.soe.vorpal"

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

################################
#Run sequence to setup vm:

echo
echo "Current VM status: ${vmnames}"
jj-soe-create-vms "${vm_names}" status

echo "Booting VMs: ${vmnames}"
jj-soe-create-vms "${vm_names}" start

echo "Waiting for VMs to boot:"
sleep 5

#operate on: "${vm_fq_names}"

echo "Connecting vis ssh key: ${vm_fq_names}"
jj-ansible-connect-play

echo "Installing Ansible requirements: ${vm_fq_names}"
jj-ansible-connect-requirements

echo "Running specific tags from the SOE: ${vm_fq_names}"
jj-ansible-soe-play-vms --tags "f27-server,f27-runlevel"

echo "Running SOE deploymemt tasks: ${vm_fq_names}"
jj-ansible-soe-play-vms

echo "Shutting down: ${vm_names}"
jj-soe-create-vms "${vm_names}" shutdown










