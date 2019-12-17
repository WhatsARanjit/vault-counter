# Vault Counter

#### Table of Contents

1. [Overview](#overview)
1. [Usage](#usage)
1. [Inputs](#inputs)

## Overview

Simply container script to run and count HashiCorp Vault entities, roles/users, 
and tokens created without entities. The script will drill into an child 
namespaces below the supplied namespace input.

## Usage

The container runs several cURL commands against the API.  Here's what it looks 
like with supplied arguments:

```shell
$ docker run --rm \
  -e VAULT_ADDR=http://my.vault.url.com:8200 \
  -e VAULT_TOKEN=$VAULT_TOKEN \
  whatsaranjit/vault_counter
Vault address: http://my.vault.url.com:8200
Total entities: 2
Total auth roles/users: 2
Total tokens: 1
```

**TLS Example**

Be sure to share the cert/key/ca into the container for use.

```
docker run --rm \
  -v $PWD/certs:/certs \
  -e VAULT_CLIENT_CERT=/certs/test.crt \
  -e VAULT_CLIENT_KEY=/certs/test.key \
  -e VAULT_CACERT=/certs/ca.crt \
  -e VAULT_ADDR=https://my.vault.url.com:8200 \
  -e VAULT_TOKEN=$VAULT_TOKEN \
  whatsaranjit/vault_counter
```

## Inputs

These are supplied to the runtime via environment variables.

* `VAULT_ADDR`

The URL to your Vault server

Default: http://127.0.0.1:8200

* `VAULT_TOKEN`

A token with enough permissions to access the `identity/` and  `sys/auth/` 
endpoints.

Default: `root`

* `VAULT_NAMESPACE`

Namespace within Vault to count along with all child namespaces.

Default: `null`

* `VAULT_CLIENT_CERT`

Path to file containing the client certificate.

Default: `null`

* `VAULT_CLIENT_KEY`

Path to file containing the client key.

Default: `null`

* `VAULT_CACERT`

Path to file containing the CA certificate.

Default: `null`

* `CURL_VERBOSE`

Set to anything to add the `-v` flag to cURL statements.

Default: `null`
