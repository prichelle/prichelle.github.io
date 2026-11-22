#!/usr/bin/env bash
# Writes app.generated.yaml: app.yaml with the certificate of certs/client-a.crt inserted.
set -eu
cd "$(dirname "$0")"
CERT=$(python3 -c 'import json,sys; print(json.dumps(open("certs/client-a.crt").read()))')
{
  grep -v '^application_public_certificate_entry' app.yaml
  echo "application_public_certificate_entry: $CERT"
} > app.generated.yaml
echo "written app.generated.yaml"
