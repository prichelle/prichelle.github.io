#!/usr/bin/env bash
# End-to-end test of the certificate-bound token flow (RFC 8705, client_credentials grant).
#
# Required environment variables (nothing is stored in this file):
#   GW_BASE        https://<gw-host>/<provider-org>/<catalog>
#   CLIENT_ID      client id of the application subscribed to mtls-payment-product
#   CLIENT_SECRET  client secret of that application
# Optional:
#   CERT_DIR       directory holding client-a.crt / client-b.crt (default: ./certs)
#   CURL_OPTS      extra curl options (default: "-k --http1.1")
set -u
: "${GW_BASE:?set GW_BASE}" "${CLIENT_ID:?set CLIENT_ID}" "${CLIENT_SECRET:?set CLIENT_SECRET}"
CERT_DIR="${CERT_DIR:-$(dirname "$0")/certs}"
CURL="curl -s ${CURL_OPTS:--k --http1.1}"
TOKEN_URL="$GW_BASE/mtls-oauth/oauth2/token"
API_URL="$GW_BASE/mtls-payment/payment"
PASS=0; FAIL=0

check() { # label expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$3"
  else FAIL=$((FAIL+1)); printf 'FAIL  %-58s expected %s got %s\n' "$1" "$2" "$3"; fi
}

# base64 DER of a certificate, no armor, one line (value of the x-client-certificate header)
cert_b64() { grep -v -- '-----' "$CERT_DIR/$1.crt" | tr -d '\n'; }

token() { # cert-name (or "none") -> prints access_token (empty when refused)
  local hdr=()
  [ "$1" != none ] && hdr=(-H "x-client-certificate: $(cert_b64 "$1")")
  $CURL -X POST "$TOKEN_URL" "${hdr[@]}" -d grant_type=client_credentials \
    -d client_id="$CLIENT_ID" -d client_secret="$CLIENT_SECRET" -d scope=payment \
    | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")'
}
call() { # token cert-name (or none) -> http status
  local hdr=() auth=()
  [ "$2" != none ] && hdr=(-H "x-client-certificate: $(cert_b64 "$2")")
  [ -n "$1" ] && auth=(-H "Authorization: Bearer $1")
  $CURL -o /dev/null -w '%{http_code}' "${hdr[@]}" "${auth[@]}" "$API_URL"
}

echo "== 1. Token endpoint"
TA=$(token client-a)
check "token with certificate client-a"       yes "$([ -n "$TA" ] && echo yes || echo no)"
check "token without certificate is refused"  no  "$([ -n "$(token none)" ] && echo yes || echo no)"

echo "== 2. Protected API"
check "token(client-a) + certificate client-a"  200 "$(call "$TA" client-a)"
check "token(client-a) + certificate client-b"  401 "$(call "$TA" client-b)"
check "token(client-a) + no certificate"        401 "$(call "$TA" none)"
TB=$(token client-b)
check "token(client-b) + certificate client-a"  401 "$(call "$TB" client-a)"
check "no token + certificate client-a"         401 "$(call "" client-a)"
check "garbage token + certificate client-a"    401 "$(call abc client-a)"

echo "response of the successful call:"
$CURL -H "x-client-certificate: $(cert_b64 client-a)" -H "Authorization: Bearer $TA" "$API_URL"; echo

echo; echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
