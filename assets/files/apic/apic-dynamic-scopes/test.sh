#!/usr/bin/env bash
# End-to-end test of the dynamic scope flow (client_credentials grant).
#
# Required environment variables (nothing is stored in this file):
#   GW_BASE        https://<gw-host>/<provider-org>/<catalog>
#   CLIENT_ID      client id of the application subscribed to echo-dynamic-oauth-product
#   CLIENT_SECRET  client secret of that application
# Optional:
#   CURL_OPTS      extra curl options, e.g. "-k" for a self-signed gateway certificate
#   CONSENT_ID     UUID used for the dynamic scope (default below)
set -u
: "${GW_BASE:?set GW_BASE}" "${CLIENT_ID:?set CLIENT_ID}" "${CLIENT_SECRET:?set CLIENT_SECRET}"
CONSENT_ID="${CONSENT_ID:-3f7a9c21-8e54-4b12-98e3-d14f7b28a9c0}"
CURL="curl -s ${CURL_OPTS:-}"
TOKEN_URL="$GW_BASE/oauth-native/oauth2/token"
PASS=0; FAIL=0

check() { # label expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf 'PASS  %-62s %s\n' "$1" "$3"
  else FAIL=$((FAIL+1)); printf 'FAIL  %-62s expected %s got %s\n' "$1" "$2" "$3"; fi
}

token() { # scope -> prints access_token (empty when refused)
  $CURL -X POST "$TOKEN_URL" -d grant_type=client_credentials \
    -d client_id="$CLIENT_ID" -d client_secret="$CLIENT_SECRET" \
    --data-urlencode "scope=$1" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")'
}
token_scope() { # scope -> prints the scope stored in the token, or the error
  $CURL -X POST "$TOKEN_URL" -d grant_type=client_credentials \
    -d client_id="$CLIENT_ID" -d client_secret="$CLIENT_SECRET" \
    --data-urlencode "scope=$1" | python3 -c 'import sys,json
d=json.load(sys.stdin); print(d.get("scope") or d.get("error"))'
}
code() { $CURL -o /dev/null -w '%{http_code}' "$@"; }

echo "== 1. Scope Validator (called directly, as the provider does: GET + token_scope)"
check "validator consent"          200 "$(code -G "$GW_BASE/oauth/scope-check" --data-urlencode "token_scope=consent")"
check "validator consent:<uuid>"   200 "$(code -G "$GW_BASE/oauth/scope-check" --data-urlencode "token_scope=consent:$CONSENT_ID")"
check "validator consent:evil"     403 "$(code -G "$GW_BASE/oauth/scope-check" --data-urlencode "token_scope=consent:evil")"

echo "== 2. Token endpoint"
check "token scope=consent"        "consent"                        "$(token_scope consent)"
check "token scope=consent:<uuid>" "consent:$CONSENT_ID consent:*"  "$(token_scope "consent:$CONSENT_ID")"
check "token scope=consent:evil"   "invalid_scope"                  "$(token_scope consent:evil)"
check "token scope=other"          "invalid_scope"                  "$(token_scope other)"

echo "== 3. Echo API"
TD=$(token "consent:$CONSENT_ID"); TS=$(token consent)
ECHO="$GW_BASE/echo-dynamic/api/credential/echo"; STATUS="$GW_BASE/echo-dynamic/api/status"
post()   { code -X POST -H 'content-type: application/json' -d '{"a":1}' -H "Authorization: Bearer $1" "$ECHO"; }
get()    { code -H "Authorization: Bearer $1" "$STATUS"; }
delete() { code -X DELETE -H "Authorization: Bearer $1" "$ECHO"; }
check "POST   /api/credential/echo  dynamic token (consent:*)" 200 "$(post "$TD")"
check "POST   /api/credential/echo  static token"              401 "$(post "$TS")"
check "POST   /api/credential/echo  garbage token"             401 "$(post abc)"
check "GET    /api/status           static token (consent)"    200 "$(get "$TS")"
check "GET    /api/status           dynamic token"             401 "$(get "$TD")"
check "GET    /api/status           no token"                  401 "$(code "$STATUS")"
check "DELETE /api/credential/echo  dynamic token (consent:*)" 200 "$(delete "$TD")"
check "DELETE /api/credential/echo  static token (consent)"    200 "$(delete "$TS")"
check "DELETE /api/credential/echo  garbage token"             401 "$(delete abc)"
check "DELETE /api/credential/echo  no token"                  401 "$(code -X DELETE "$ECHO")"
echo "consentId returned by the API:"
$CURL -X POST -H 'content-type: application/json' -d '{"a":1}' -H "Authorization: Bearer $TD" "$ECHO" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("  consentId =", d.get("consentId"), "| scope =", d.get("scope"))'

echo; echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
