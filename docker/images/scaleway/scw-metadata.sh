#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [[ "$#" -gt 0 ]] && [[ "$1" == "--cached" ]]; then
    shift || true
fi

CACHE_FILE=/run/scw-metadata.cache

get_ipv4 () {
    local interface=$1

    echo "$( \
        ip addr show \
            | sed -E 's/^([a-z0-9])/^\1/' \
            | tr '\n' ' ' \
            | tr '^' '\n' \
            | grep -E "^[a-z0-9]+:[ \t]+$interface\b.+inet\b" \
            | sed -E 's/^.+inet ([^/]+).+$/\1/' \
        )"
}

if [[ ! -f "$CACHE_FILE" ]]; then
    cat <<EOF | tee "$CACHE_FILE" >/dev/null
ORGANIZATION=88826fb8-2135-487b-9b2c-fa17c5d5c02f
NAME=$(hostname)
TAGS=0
STATE_DETAIL='booted'
HOSTNAME=$(hostname)
EOF

    # assume there's a public ip if there's more than one eth device
    if [[ "$(ip addr show | grep -E '^[0-9]+:[ \t]+eth' | wc -l)" -gt 1 ]]; then
        private_interface=eth1

        cat <<EOF | tee -a "$CACHE_FILE" >/dev/null
PUBLIC_IP='DYNAMIC IP ADDRESS'
PUBLIC_IP_DYNAMIC=False
PUBLIC_IP_ID=$(uuidgen)
PUBLIC_IP_ADDRESS=$(get_ipv4 eth0)
EOF
    else
        private_interface=eth0

        cat <<EOF | tee -a "$CACHE_FILE" >/dev/null
PUBLIC_IP=
EOF
    fi

ssh_public_keys=$(grep -E '^ssh-rsa' /root/.ssh/authorized_keys 2>/dev/null || true)
ssh_public_key_index=0

    cat <<EOF | tee -a "$CACHE_FILE" >/dev/null
SSH_PUBLIC_KEYS=$(echo "$ssh_public_keys" | wc -l)
EOF

for ssh_public_key in $ssh_public_keys; do
    key_prefix="SSH_PUBLIC_KEYS_$ssh_public_key_index"

    cat <<EOF | tee -a "$CACHE_FILE" >/dev/null
$key_prefix='KEY FINGERPRINT'
${key_prefix}_KEY='$ssh_public_key'
${key_prefix}_FINGERPRINT='$(ssh-keygen -E md5 -lf <(echo $ssh_public_key))'
EOF
done

    cat <<EOF | tee -a "$CACHE_FILE" >/dev/null
BOOTSCRIPT='KERNEL TITLE DEFAULT DTB ID INITRD BOOTCMDARGS ARCHITECTURE ORGANIZATION PUBLIC'
BOOTSCRIPT_KERNEL=http://169.254.42.24/kernel/x86_64-mainline-lts-4.4-4.4.122-rev1/vmlinuz-4.4.122
BOOTSCRIPT_TITLE='x86_64 mainline 4.4.122 rev1'
BOOTSCRIPT_DEFAULT=True
BOOTSCRIPT_DTB=''
BOOTSCRIPT_ID=4eb335f4-1539-4ec1-b8f1-a284e0e2d53e
BOOTSCRIPT_INITRD=http://169.254.42.24/initrd/initrd-Linux-x86_64-v3.13.0.gz
BOOTSCRIPT_BOOTCMDARGS='LINUX_COMMON scaleway boot=local'
BOOTSCRIPT_ARCHITECTURE=x86_64
BOOTSCRIPT_ORGANIZATION=11111111-1111-4111-8111-111111111111
BOOTSCRIPT_PUBLIC=True
PRIVATE_IP=$(get_ipv4 "$private_interface")
VOLUMES=0
VOLUMES_0='NAME MODIFICATION_DATE EXPORT_URI VOLUME_TYPE CREATION_DATE ORGANIZATION SERVER ID SIZE'
VOLUMES_0_NAME=x86_64-ubuntu-xenial-2017-01-05_09:58
VOLUMES_0_MODIFICATION_DATE=$(date '+%Y-%m-%dT%H:%M:%S.%6N%:z')
VOLUMES_0_EXPORT_URI=device://dev/vda
VOLUMES_0_VOLUME_TYPE=l_ssd
VOLUMES_0_CREATION_DATE=$(date '+%Y-%m-%dT%H:%M:%S.%6N%:z')
VOLUMES_0_ORGANIZATION=88826fb8-2135-487b-9b2c-fa17c5d5c02f
VOLUMES_0_SERVER='ID NAME'
VOLUMES_0_SERVER_ID=$(uuidgen)
VOLUMES_0_SERVER_NAME=$(hostname)
VOLUMES_0_ID=$(uuidgen)
VOLUMES_0_SIZE=$(df -H / | tail -n1 | awk '{ print $2 }' | sed 's/G/000000000/')
IPV6=
TIMEZONE=UTC
COMMERCIAL_TYPE=VC1S
ID=$(uuidgen)
EXTRA_NETWORKS=0
LOCATION='PLATFORM_ID HYPERVISOR_ID NODE_ID CLUSTER_ID ZONE_ID'
LOCATION_PLATFORM_ID=12
LOCATION_HYPERVISOR_ID=$((1 + RANDOM % 200))
LOCATION_NODE_ID=$((1 + RANDOM % 200))
LOCATION_CLUSTER_ID=93
LOCATION_ZONE_ID=par1
EOF
fi

BODY=$(cat "$CACHE_FILE")

if [[ "$#" -gt 0 ]]; then
    BODY=$(echo "$BODY" | grep "^$1=" | sed "s/^[^=]*=//;s/^['\"]//;s/['\"]$//")
fi

echo "$BODY"
