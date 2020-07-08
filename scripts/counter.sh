#!/bin/bash

if [ -z "$JSON_OUTPUT" ]
then
  echo "Vault address: ${VAULT_ADDR}"
else
  OUTPUT="{\"VAULT_ADDR\": \"${VAULT_ADDR}\"}"
fi
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
  if [ -z "$SKIP_ORPHAN_TOKENS" ]
  then
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
  fi

  echo "$TOTAL_ENTITIES,$TOTAL_ROLES,$TOTAL_TOKENS,$TOTAL_ORPHAN_TOKENS"
}

function output() {
  # Transform comma-separated list into output
  array=($(echo $1 | sed 's/,/ /g'))
  # Create plain or JSON output
  if [ -z "$JSON_OUTPUT" ]
  then
    OUTPUT="Total entities: ${array[0]}"
    OUTPUT="${OUTPUT}\nTotal users/roles: ${array[1]}"
    OUTPUT="${OUTPUT}\nTotal tokens: ${array[2]}"
    if [ -z "$SKIP_ORPHAN_TOKENS" ]
    then
      OUTPUT="${OUTPUT}\nTotal orphan tokens: ${array[3]}"
    fi
    echo -e $OUTPUT
  else
    new="{ \"namespaces\": { \"${VAULT_NAMESPACE}\": { \"entities\": ${array[0]}, \"users/roles\": ${array[1]}, \"tokens\": ${array[2]}"
    if [ -z "$SKIP_ORPHAN_TOKENS" ]
    then
      new="${new}, \"orphan tokens\": ${array[3]}"
    fi
    new="${new} } } }"
    OUTPUT=$(jq -s '.[0] * .[1]' <(echo $OUTPUT) <(echo $new))
  fi
}

function drill_in() {
  # Run counts where we stand
  VAULT_NAMESPACE=$1

  if [ -z "$JSON_OUTPUT" ]
  then
    echo "Namespace: $1"
  fi
  counts=$(count_things $1)
  output $counts

  # Pull all namespaces from current position, if any
  NAMESPACE_LIST=$(vault_curl \
    --request LIST \
    $VAULT_ADDR/v1/sys/namespaces | \
    jq -r '.? | .["data"]["keys"] | @tsv')

  if [ ! -z "$NAMESPACE_LIST" ]
  then
    if [ -z "$JSON_OUTPUT" ]
    then
      echo "$1 child namespaces: $NAMESPACE_LIST"
    fi
    for ns in $NAMESPACE_LIST; do
      path=$(echo $1 | sed -e 's%^root%%')
      drill_in "${path}${ns}"
    done
  fi
}

drill_in $VAULT_NAMESPACE

# Add totals to JSON
if [ ! -z "$JSON_OUTPUT" ]
then
  total_entities=$(echo $OUTPUT | jq '.namespaces | [.[].entities] | add')
  total_users=$(echo $OUTPUT | jq '.namespaces | [.[]."users/roles"] | add')
  total_tokens=$(echo $OUTPUT | jq '.namespaces | [.[].tokens] | add')
  totals="{ \"totals\": { \"entities\": $total_entities, \"users/roles\": $total_users, \"tokens\": $total_tokens"
  if [ -z "$SKIP_ORPHAN_TOKENS" ]
  then
    total_orphans=$(echo $OUTPUT | jq '.namespaces | [.[]."orphan tokens"] | add')
    totals="${totals}, \"orphan tokens\": ${total_orphans}"
  fi
  totals="${totals} } }"
  OUTPUT=$(jq -s '.[0] * .[1]' <(echo $OUTPUT) <(echo $totals))
  echo $OUTPUT
fi
