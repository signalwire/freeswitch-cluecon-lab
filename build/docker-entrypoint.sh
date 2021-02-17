#!/bin/bash
set -e

if [ "$1" = 'freeswitch' ] && [ -f "/letsencrypt/certs/cert.pem" ]; then
  /usr/bin/freeswitch -nonat -c -rp
fi

exec "$@"