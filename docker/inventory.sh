#!/bin/bash

set -eo pipefail
IFS=$'\n\t'

PROXY_0_SSH_PORT=${PROXY_0_SSH_PORT:-2222}
PROXY_TEST_TIMEOUT=${PROXY_TEST_TIMEOUT:-2.0}

cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker-compose up -d >/dev/null

sleep 0.5

PRIVATE_ADDRESSES=$( \
    docker-compose ps \
        | awk '$0 ~ /Up/ { print $1 }' \
        | xargs -I@ sh -c "/bin/echo -n '@ '; docker exec @ ip addr show eth0 | grep -o 'inet [^/]*' | cut -d' ' -f 2" \
        | sed -E 's/^.+_([a-z]+[0-9]+)_[0-9]+ /\1 /'
    )

get_proxy_hosts ()
{
    {
        i=0
        for host in $(echo "$PRIVATE_ADDRESSES" | grep -E "^proxy"); do
            if [ $i -eq 0 ]; then
                echo "$host" | awk '{ print $1":\n  ansible_host: 127.0.0.1 # "$2 }'
                echo "  ansible_port: $PROXY_0_SSH_PORT"
                echo "  tinc_private_interface: eth1"
            else
                echo "$host" | awk '{ print $1":\n  ansible_host: "$2 }'
                echo "  ansible_ssh_common_args: -o ProxyCommand=\"ssh -q -C -o ControlMaster=auto -o ControlPersist=5m -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 -p $PROXY_0_SSH_PORT -W %h:%p\""
            fi
            echo "  vpn_ip: 192.168.66.$vpn_id"
            i=$(expr $i + 1)
            vpn_id=$(expr $vpn_id + 1)
        done
    } | sed -E "s/^/    /"
}

get_private_hosts ()
{
    local role=$1

    {
        for host in $(echo "$PRIVATE_ADDRESSES" | grep -E "^$role"); do
            echo "$host" | awk '{ print $1":\n  ansible_host: "$2 }'
            echo "  vpn_ip: 192.168.66.$vpn_id"
            vpn_id=$(expr $vpn_id + 1)
        done
    } | sed -E "s/^/    /"
}

vpn_id=1

cat <<EOF | tee inventories/docker.yml
all:
  vars:
    basic_auth_user: admin
    basic_auth_password: admin
    kubeadm_ignore_preflight_errors: all
    kubelet_fail_swap_on: False
    proxy_private_interface: eth1
    proxy_test_timeout: $PROXY_TEST_TIMEOUT
    # scaleway_ipaddr: x.x.x.x
    # scaleway_reverse_ipaddr: domain.tld
    tinc_ignore_scaleway_dns: True

proxy:
  hosts:
$(get_proxy_hosts "proxy" $PROXY_COUNT)

EOF
vpn_id=$(expr $vpn_id + $(echo "$PRIVATE_ADDRESSES" | grep -E "^proxy" | wc -l | awk '{ print $1 }'))

cat <<EOF | tee -a inventories/docker.yml
masters:
  hosts:
$(get_private_hosts "master" $MASTER_COUNT)

EOF
vpn_id=$(expr $vpn_id + $(echo "$PRIVATE_ADDRESSES" | grep -E "^master" | wc -l | awk '{ print $1 }'))

cat <<EOF | tee -a inventories/docker.yml
workers:
  hosts:
$(get_private_hosts "worker" $WORKER_COUNT)
EOF
vpn_id=$(expr $vpn_id + $(echo "$PRIVATE_ADDRESSES" | grep -E "^worker" | wc -l | awk '{ print $1 }'))
