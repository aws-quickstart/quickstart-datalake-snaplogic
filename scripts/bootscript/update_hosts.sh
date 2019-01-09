#!/usr/bin/env bash

set -u

user_id=$(id -u)

# requires sudo
[ "${user_id}" -ne 0 ] && echo "update_hosts must be run as root" && exit 1

user="${1:-ec2-user}"

update_hosts_script_path=$(readlink -e "${BASH_SOURCE[0]}")
update_hosts_script_dir="${update_hosts_script_path%/*}"

# ec2-metadata script must be ini the same directory
[ ! -e "${update_hosts_script_dir}/ec2-metadata" ] && echo "ec2-metadata script must be in the same directory as create-instance-env.sh" && exit 1


function parse_metadata_result() {
    local metadata="${1}"
    local value="${metadata#*: }"
    echo "${value}"
}

local_hostname=$("${update_hosts_script_dir}/ec2-metadata" -h)
local_hostname=$(parse_metadata_result "${local_hostname}")

# ec2 instances on public subnets have host names that do not end in ec2.internal and hence do not match their private DNS
# ec2 instances on private subnets have host names that do end in ec2.internal and hence match their private DNS

private_dns="${local_hostname%.ec2.internal}.ec2.internal"

local_ipv4=$("${update_hosts_script_dir}/ec2-metadata" -o)
local_ipv4=$(parse_metadata_result "${local_ipv4}")
public_hostname=$("${update_hosts_script_dir}/ec2-metadata" -p)
public_hostname=$(parse_metadata_result "${public_hostname}")
public_ipv4=$("${update_hosts_script_dir}/ec2-metadata" -v)
public_ipv4=$(parse_metadata_result "${public_ipv4}")

if [ -z "${public_ipv4}" ] || [ "${public_ipv4}" == "not available" ] || [ -z "${public_hostname}" ] || [ "${public_hostname}" == "not available" ]; then
    public_hostname=""
fi

echo "${local_ipv4}    ${private_dns} ${public_hostname}" >> /etc/hosts

sed -i "s/HOSTNAME=.*/HOSTNAME=${private_dns}/g" /etc/sysconfig/network
sudo hostname "${private_dns}"

sudo service network restart

echo "hostname=$(hostname)" | tee -a "/home/${user}/update_hosts.log"
echo "hostname -i=$(hostname -i)" | tee -a "/home/${user}/update_hosts.log"
echo "hostname -I=$(hostname -I)" | tee -a "/home/${user}/update_hosts.log"
echo "hostname -f=$(hostname -f)" | tee -a "/home/${user}/update_hosts.log"
echo "hostname -A=$(hostname -A)" | tee -a "/home/${user}/update_hosts.log"

echo "finished update_hosts"