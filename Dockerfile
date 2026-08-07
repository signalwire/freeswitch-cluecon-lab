# syntax=docker/dockerfile:1.7
# vim:set ft=dockerfile:

# Debian 13 "trixie" - stable since 2025-08-09, supported through 2028.
# FreeSWITCH 1.11.0 added official trixie packages. Do not go back to
# bullseye: Debian 11 left LTS on 2026-08-31.
FROM debian:trixie

# explicitly set user/group IDs
RUN groupadd -r freeswitch --gid=999 && useradd -r -g freeswitch --uid=999 freeswitch

# make the "en_US.UTF-8" locale so freeswitch will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.utf8

# FreeSWITCH Community packages.
#
# The SignalWire token arrives as a BuildKit secret rather than an ARG, so it
# never lands in an image layer or in `docker history`. Everything needing it
# happens in this single RUN, and both the credentials and the authenticated
# repo are deleted before the layer is committed - so a leaked image cannot
# leak the token. (Re-run `fsget` inside the container if you later need to
# install more FreeSWITCH packages.)
#
# The hostname shim is here because the freeswitch postinst wants a resolvable
# hostname, which a build container does not have.
RUN --mount=type=secret,id=signalwire_token,required=true \
    apt-get update && apt-get install -y \
        apt-transport-https ca-certificates curl dnsutils gnupg2 gosu lsb-release openssl wget \
    && TOKEN="$(cat /run/secrets/signalwire_token)" \
    && curl --fail --silent --show-error \
        --user "signalwire:${TOKEN}" \
        --output /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
        https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg \
    && printf '%s\n' \
        'Types: deb deb-src' \
        'URIs: https://freeswitch.signalwire.com/repo/deb/debian-release/' \
        "Suites: $(lsb_release -sc)" \
        'Components: main' \
        'Signed-By: /usr/share/keyrings/signalwire-freeswitch-repo.gpg' \
        > /etc/apt/sources.list.d/freeswitch.sources \
    && printf 'machine freeswitch.signalwire.com login signalwire password %s\n' "${TOKEN}" \
        > /etc/apt/auth.conf \
    && chmod 600 /etc/apt/auth.conf \
    && mv /bin/hostname /bin/hostname.bkp \
    && echo "echo myhost.local" > /bin/hostname \
    && chmod +x /bin/hostname \
    && apt-get update \
    && apt-get install -y freeswitch-meta-all \
    && mv /bin/hostname.bkp /bin/hostname \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/apt/auth.conf /etc/apt/sources.list.d/freeswitch.sources

## Ports
# Open the container up to the world.
### 8021 fs_cli, 5060 5061 5080 5081 sip and sips, 8081 8082 verto ws/wss,
### 16384-32768 rtp
EXPOSE 443/tcp
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 6050/tcp 6050/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 7443/tcp
EXPOSE 5070/udp 5070/tcp
# mod_verto: ws and wss, per conf/autoload_configs/verto.conf.xml
EXPOSE 8081/tcp 8082/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp

# Limits Configuration
COPY build/freeswitch.limits.conf /etc/security/limits.d/

COPY build/docker-entrypoint.sh /

# Healthcheck to make sure the service is running
SHELL       ["/bin/bash", "-c"]
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s \
    CMD  fs_cli -x status | grep -q ^UP || exit 1

## Add additional things here

##

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["freeswitch"]
