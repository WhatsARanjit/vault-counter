path "identity/entity/id" {
  capabilities = ["list"]
}

path "sys/auth" {
  capabilities = ["read"]
}

path "auth/*" {
  capabilities = ["read", "list"]
}

path "sys/namespaces" {
  capabilities = ["list"]
}
