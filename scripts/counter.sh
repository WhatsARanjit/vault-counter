#!/bin/bash

echo "Vault address: ${VAULT_ADDR}"
# Set namespace to root if nothing
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"root/"}

function vault_curl() {
  curl -sk \
  ${CURL_VERBOSE:+"-v"} \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
  --cert   "$VAULT_CLIENT_CERT" \
  --key    "$VAULT_CLIENT_KEY" \
  --cacert "$VAULT_CACERT" \
  "$@"
}

function count_things() {
  VAULT_NAMESPACE=$1

  # Entities
  TOTAL_ENTITIES=$(vault_curl \
    --request LIST \
    $VAULT_ADDR/v1/identity/entity/id | \
    jq -r '.? | .["data"]["keys"] | length')

  # Roles
  TOTAL_ROLES=0
  for mount in $(vault_curl \
   --request GET \
   $VAULT_ADDR/v1/sys/auth | \
   jq -r '.? | .["data"] | keys[]');
  do
   users=$(vault_curl \
     --request LIST \
     $VAULT_ADDR/v1/auth/${mount}users | \
     jq -r '.? | .["data"]["keys"] | length')
   role=$(vault_curl \
     --request LIST \
     $VAULT_ADDR/v1/auth/${mount}role | \
     jq -r '.? | .["data"]["keys"] | length')
   roles=$(vault_curl \
     --request LIST \
     $VAULT_ADDR/v1/auth/${mount}roles | \
     jq -r '.? | .["data"]["keys"] | length')
   certs=$(vault_curl \
     --request LIST \
     $VAULT_ADDR/v1/auth/${mount}certs | \
     jq -r '.? | .["data"]["keys"] | length')
   groups=$(vault_curl \
     --request LIST \
     $VAULT_ADDR/v1/auth/${mount}groups | \
     jq -r '.? | .["data"]["keys"] | length')
   TOTAL_ROLES=$((TOTAL_ROLES + users + role + roles + certs + groups))
  done

  # Tokens
  TOTAL_TOKENS_RAW=$(vault_curl \
   --request LIST \
   $VAULT_ADDR/v1/auth/token/accessors
  )
  TOTAL_TOKENS=$(echo $TOTAL_TOKENS_RAW | jq -r '.? | .["data"]["keys"] | length')
  TOTAL_ORPHAN_TOKENS=0
  for accessor in $(echo $TOTAL_TOKENS_RAW | \
   jq -r '.? | .["data"]["keys"] | join("\n")');
  do
   token=$(vault_curl \
     --request POST \
     -d "{ \"accessor\": \"${accessor}\" }" \
     $VAULT_ADDR/v1/auth/token/lookup-accessor | \
     jq -r '.? | .| [select(.data.path == "auth/token/create")] | length')
   TOTAL_ORPHAN_TOKENS=$((TOTAL_ORPHAN_TOKENS + $token))
  done

  echo "$TOTAL_ENTITIES,$TOTAL_ROLES,$TOTAL_TOKENS,$TOTAL_ORPHAN_TOKENS"
}

function output() {
  # Transform comma-separated list into output
  array=($(echo $1 | sed 's/,/ /g'))
  echo "Total entities: ${array[0]}"
  echo "Total users/roles: ${array[1]}"
  echo "Total tokens: ${array[2]}"
  echo "Total orphan tokens: ${array[3]}"
}

function drill_in() {
  # Run counts where we stand
  VAULT_NAMESPACE=$1

  echo "Namespace: $1"
  counts=$(count_things $1)
  output $counts

  # Pull all namespaces from current position, if any
  NAMESPACE_LIST=$(vault_curl \
    --request LIST \
    $VAULT_ADDR/v1/sys/namespaces | \
    jq -r '.? | .["data"]["keys"] | @tsv')

  if [ ! -z "$NAMESPACE_LIST" ]
  then
    echo "$1 child namespaces: $NAMESPACE_LIST"
    for ns in $NAMESPACE_LIST; do
      drill_in $ns
    done
  fi
}

drill_in $VAULT_NAMESPACE
