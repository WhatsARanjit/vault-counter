#!/bin/bash

echo "Vault address: ${VAULT_ADDR}"

function vault_curl() {
  curl -sk \
  ${CURL_VERBOSE:+"-v"} \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --cert   "$VAULT_CLIENT_CERT" \
  --key    "$VAULT_CLIENT_KEY" \
  --cacert "$VAULT_CACERT" \
  "$@"
}

# Entities
TOTAL_ENTITIES=$(vault_curl \
  --request LIST \
  $VAULT_ADDR/v1/identity/entity/id | \
  jq -r '.["data"]["keys"] | length')
echo "Total entities: $TOTAL_ENTITIES"

# Roles
TOTAL_ROLES=0
for mount in $(vault_curl \
 $VAULT_ADDR/v1/sys/auth | \
 jq -r '.["data"] | keys[]');
do
 users=$(vault_curl \
   --request LIST \
   $VAULT_ADDR/v1/auth/${mount}users | \
   jq -r '.["data"]["keys"] | length')
 roles=$(vault_curl \
   --request LIST \
   $VAULT_ADDR/v1/auth/${mount}roles | \
   jq -r '.["data"]["keys"] | length')
 TOTAL_ROLES=$((TOTAL_ROLES + users + roles))
done
echo "Total auth roles/users: $TOTAL_ROLES"

# Tokens
TOTAL_TOKENS=0
for accessor in $(vault_curl \
 --request LIST \
 $VAULT_ADDR/v1/auth/token/accessors | \
 jq -r '.["data"]["keys"] | join("\n")');
do
 token=$(vault_curl \
   --request POST \
   -d "{ \"accessor\": \"${accessor}\" }" \
   $VAULT_ADDR/v1/auth/token/lookup-accessor | \
   jq -r '.| [select(.data.path == "auth/token/create")] | length')
 TOTAL_TOKENS=$((TOTAL_TOKENS + $token))
done
echo "Total tokens: $TOTAL_TOKENS"
