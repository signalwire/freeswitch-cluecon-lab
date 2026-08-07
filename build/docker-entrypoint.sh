#!/bin/bash
set -euo pipefail

CERTS_DIR="${FREESWITCH_CERTS_DIR:-/etc/freeswitch/tls}"
LETSENCRYPT_DIR="${LETSENCRYPT_DIR:-/letsencrypt/certs}"

# Build the combined PEMs mod_verto and mod_sofia expect.
#
# If Let's Encrypt certificates have been mounted in, use those; otherwise
# generate a self-signed pair on first boot. These are deliberately NOT
# committed to the repo - a private key in public git is worthless as a secret
# and actively misleading. They land in the bind-mounted ./conf/tls on the
# host, so they survive a container restart.
setup_certs() {
  mkdir -p "$CERTS_DIR"

  if [ -f "$LETSENCRYPT_DIR/fullchain.pem" ] && [ -f "$LETSENCRYPT_DIR/privkey.pem" ]; then
    echo "entrypoint: installing Let's Encrypt certificates from $LETSENCRYPT_DIR"
    cat "$LETSENCRYPT_DIR/fullchain.pem" "$LETSENCRYPT_DIR/privkey.pem" > "$CERTS_DIR/wss.pem"
    cp "$CERTS_DIR/wss.pem" "$CERTS_DIR/tls.pem"
  elif [ ! -f "$CERTS_DIR/wss.pem" ]; then
    echo "entrypoint: generating self-signed certificates in $CERTS_DIR"
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -subj "/C=US/CN=FreeSWITCH" \
      -keyout "$CERTS_DIR/.key.tmp" -out "$CERTS_DIR/.crt.tmp" 2>/dev/null
    cat "$CERTS_DIR/.crt.tmp" "$CERTS_DIR/.key.tmp" > "$CERTS_DIR/wss.pem"
    cp "$CERTS_DIR/wss.pem" "$CERTS_DIR/tls.pem"
    rm -f "$CERTS_DIR/.key.tmp" "$CERTS_DIR/.crt.tmp"
  fi

  # Deliberately NOT generating dtls-srtp.pem here. FreeSWITCH creates its own
  # on startup and enforces a key length longer than 2048 bits
  # (switch_core_cert.c), so anything we generate is rejected, renamed to
  # .pem.old and replaced - leaving confusing litter behind. Let the core own it.

  chmod 600 "$CERTS_DIR"/wss.pem "$CERTS_DIR"/tls.pem
}

if [ "${1:-}" = 'freeswitch' ]; then
  setup_certs
  shift
  # Run in the foreground as PID 1 so Docker sees the real process, signals are
  # delivered, and the HEALTHCHECK means something. Extra flags from the compose
  # `command:` (-nonat, -nonatmap, ...) are passed straight through.
  exec freeswitch -c "$@"
fi

exec "$@"
