FROM scaleway/ubuntu:amd64-xenial
MAINTAINER Andrew Mackrodt <andrew@denimsoft.com>

RUN apt-mark hold systemd \
    && echo "root:docker" | chpasswd \
    && sed -i -E "s/^StrictModes yes/StrictModes no/" /etc/ssh/sshd_config

ENV container docker
ENV XDG_RUNTIME_DIR /run/user/0

EXPOSE 22

ADD docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ADD resolv.conf /etc/resolv.conf.default
ADD scw-metadata.sh /usr/local/bin/scw-metadata
ADD scw-userdata.sh /usr/local/sbin/scw-userdata

RUN sed -i -E "s/^ip=.+/ip=\$(scw-metadata --cached PRIVATE_IP)/" /etc/update-motd.d/50-scw

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
