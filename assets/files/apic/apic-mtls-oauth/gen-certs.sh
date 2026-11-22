#!/usr/bin/env bash
# Generates two self-signed client certificates (RFC 8705 "self_signed_tls_client_auth"):
#   client-a : the certificate registered on the API Connect application
#   client-b : an unrelated certificate, used for the negative tests
# Private keys stay in ./certs (git-ignored). Nothing here is a secret worth keeping: test material only.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs
for c in client-a client-b; do
  [ -f certs/$c.key ] && continue
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
    -keyout certs/$c.key -out certs/$c.crt \
    -subj "/O=Example/CN=$c" \
    -addext "keyUsage=digitalSignature" -addext "extendedKeyUsage=clientAuth" 2>/dev/null
done
for c in client-a client-b; do
  printf '%s  x5t#S256=' "$c"
  openssl x509 -in certs/$c.crt -outform DER | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='
  echo
done
