# vim:set ft=dockerfile:
FROM debian:bullseye

ARG SIGNALWIRE_TOKEN

# Source Dockerfile:
# https://github.com/docker-library/postgres/blob/master/9.4/Dockerfile

# explicitly set user/group IDs
RUN groupadd -r freeswitch --gid=999 && useradd -r -g freeswitch --uid=999 freeswitch


# make the "en_US.UTF-8" locale so freeswitch will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales wget && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN apt-get update && apt-get install -y gosu curl gnupg2 wget lsb-release apt-transport-https ca-certificates \
    && wget --http-user=signalwire --http-password=$SIGNALWIRE_TOKEN -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-unstable/signalwire-freeswitch-repo.gpg \
    && echo "machine freeswitch.signalwire.com login signalwire password $SIGNALWIRE_TOKEN" > /etc/apt/auth.conf \
    && echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list \
    && echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list

RUN cat /etc/apt/sources.list.d/freeswitch.list

RUN mv /bin/hostname /bin/hostname.bkp; \
  echo "echo myhost.local" > /bin/hostname; \
  chmod +x /bin/hostname

RUN apt-get update && apt-get install -y freeswitch-meta-all
RUN apt-get update && apt-get install -y dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mv /bin/hostname.bkp /bin/hostname
# Clean up
RUN apt-get autoremove

## Ports
# Open the container up to the world.
### 8021 fs_cli, 5060 5061 5080 5081 sip and sips, 64535-65535 rtp
EXPOSE 443/tcp
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 6050/tcp 6050/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 7443/tcp
EXPOSE 5070/udp 5070/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp

# Limits Configuration
COPY build/freeswitch.limits.conf /etc/security/limits.d/

COPY build/docker-entrypoint.sh /

# Healthcheck to make sure the service is running
SHELL       ["/bin/bash"]
HEALTHCHECK --interval=15s --timeout=5s \
    CMD  fs_cli -x status | grep -q ^UP || exit 1

## Add additional things here

##

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["freeswitch"]
