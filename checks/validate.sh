#!/bin/bash

VAULT_VERSION=${VAULT_VERSION:-"1.4.2"}

# Check bash syntas
bash -n scripts/*

# Grab vault binary
if [ ! -f "vault" ]; then
  rm -rf vault.zip vault
  curl -o vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}+ent_darwin_amd64.zip"
  unzip vault.zip
fi

# Start Vault server in the background
nohup ./vault server -dev -dev-root-token-id='root' &
sleep 5
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# Generic function
function configure_namespace() {
  # Find parent and target namespaces
  export VAULT_TOKEN=root
  parent=$(dirname $1)
  ns=$(basename $1)
  # If in root namespace, no parent
  if [ "$parent" = "." ]; then
    parent=''
  fi
  # Change to parent
  export VAULT_NAMESPACE=$parent
  # Create namespace if not root
  if [ "$1" != "root/" ]; then
    ./vault namespace create $ns
  fi
  # Create a number of tokens based on namespace length
  export VAULT_NAMESPACE=$1
  len=$(echo $1 | wc -c)
  for i in $(seq 1 $len); do
    ./vault token create
  done
  ./vault auth enable userpass
  ./vault write auth/userpass/users/mitchellh \
    password=foo
  ./vault write auth/userpass/users/armond \
    password=foo
   unset VAULT_TOKEN
  ./vault login -method=userpass \
    username=armond \
    password=foo
}

# Configure stuff
# Root namespace
configure_namespace 'root/'

# Dev namespace
configure_namespace 'dev/'

# Subdev namespace
configure_namespace 'dev/subdev/'

# Run script
unset VAULT_NAMESPACE
export VAULT_TOKEN=root
results=$(mktemp)
./scripts/counter.sh > $results
diff $results checks/pass.out
code=$?

# Bail out
pkill -9 vault
exit $code
