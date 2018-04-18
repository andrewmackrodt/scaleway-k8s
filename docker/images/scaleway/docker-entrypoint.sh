#!/bin/bash
#
# The majority if tis file is to deal with docker-in-docker
#

set -euo pipefail
IFS=$'\n\t'

# get scaleway metadata address
METADATA_IP=$(getent hosts metadata | awk '{ print $1 }')

if [ ! -f /etc/iptables/rules.v4 ]; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

# remove docker postrouting rules from the previous run
cat /etc/iptables/rules.v4 \
    | tr '\n' '~' \
    | sed -E 's/(~:DOCKER_POSTROUTING[^~]+(~-[^~]+)*)+/~# *docker/' \
    | tr '~' '\n' \
    | tee /etc/iptables/rules.v4.tmp >/dev/null

# replace them with the current rules, except where dns is involved
DOCKER_POSTROUTING_RULES=$(iptables-save \
    | tr '\n' '~' \
    | sed -E 's/^.+(~(:DOCKER_POSTROUTING[^~]+(~-[^~]+)*)+).+$/\1/' \
    | tr '~' '\n' \
    | grep -v -E -- '--dport 53 -j DNAT|-j SNAT --to-source :53' \
    | tr '\n' '~' \
    | sed 's/~/\\n/g')

# save the modified rules
cat /etc/iptables/rules.v4.tmp \
    | sed "s@# \*docker@${DOCKER_POSTROUTING_RULES}@" \
    | grep -v -E '^$' \
    | tee /etc/iptables/rules.v4 >/dev/null

# remove the temp file
rm -f /etc/iptables/rules.v4.tmp

# reload iptables
iptables-restore < /etc/iptables/rules.v4

# replace the hosts file to make it writable
cp -p /etc/hosts /etc/hosts.tmp
umount /etc/hosts
mv /etc/hosts.tmp /etc/hosts

# replace the authorized keys file to make it writable
if [[ $(mount | awk '$3 == "/root/.ssh/authorized_keys" { print 1 }') -eq 1 ]]; then
    cp -p /root/.ssh/authorized_keys /tmp/authorized_keys
    umount /root/.ssh/authorized_keys
    mv /tmp/authorized_keys /root/.ssh/authorized_keys
fi

# remount /proc/sys as rw
mount -o remount rw /proc/sys

# remount /run as shared
mount --make-shared /run

# create directories for systemd init
mkdir -p /run/lock /run/user/0
mount -t tmpfs -o nosuid,nodev,noexec,relatime,size=5120k tmpfs /run/lock
mount -t tmpfs -o nosuid,nodev,relatime,size=204800k,mode=700 tmpfs /run/user/0

# remove docker dns lookup from /etc/resolv.conf
ex '+g/nameserver 127.0.0.11/d' -cwq /etc/resolv.conf >/dev/null
if [ ! `grep -q '1.1.1.1' /etc/hosts` ]; then
    cat /etc/resolv.conf.default >> /etc/resolv.conf
fi

# redirect scaleway metadata address requests
PRIVATE_INTERFACE=$(ip route get "$METADATA_IP" | head -n1 | sed -E 's/^.+dev ([^ ]+).+$/\1/')
ip route add 169.254.42.42 dev "$PRIVATE_INTERFACE"
iptables -t nat -A OUTPUT -d 169.254.42.42 -j DNAT --to-destination "$METADATA_IP"

# scaleway image routing fix when dual eth
for link in $(ip route | awk '$3 ~ /^eth/ && $7 == "link" { print $1 }'); do
    ip route replace "$link" via "$(echo "$link" | sed -E 's/\.[0-9]+\/[0-9]+$/.1/')"
done

# execute the init system
exec /sbin/init
