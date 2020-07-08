## 2020-07-08 - Release 0.0.7

### Summary

- Added JSON output format

## 2020-06-23 - Release 0.0.6

### Summary

- Drilling into child-child namespaces correctly

#### Bugfixes

* Was losing the parent path when drilling into child namespaces, meaning if the
 path were `org/program/bu`, I was losing `org/program` and just drilling into `bu`.
Added a `SKIP_ORPHAN_TOKENS` option in case inspecting each token isn't necessary
 because this is an expensive operation.

## 2020-06-19 - Release 0.0.5

### Summary

- Adding more endpoints for auth

#### Bugfixes

- The different auth methods have different endpoints to count:
  - userpass: `/user`
  - pki: `/certs`
  - aws: `/roles`
  - azure: `/role`
  - ldap: `/users` and `/groups`

## 2020-01-31 - Release 0.0.4

### Summary

- Distinguising auth method tokens from others

## 2019-12-17 - Release 0.0.2

### Summary

- Adding in child namespace ability

## 2019-12-12 - Release 0.0.1

### Summary

- Initial commit; count things
