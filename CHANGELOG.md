## Release 0.2.0

#### Summary

This is a feature and bugfix release.

#### Features
* (MODULES-4542) Support YAML and JSON output formats for `puppet certregen healthcheck`.
* (MODULES-4681) Support for Puppet `strict_variables` compiler setting.

#### Bugfixes

* (MODULES-4523) Return expiration of new CA cert for `puppet certregen ca`; previously the expiration of the old CA certificate was returned.
* (MODULES-4659) Remove usage of APIs deprecated in Puppet 5

## Release 0.1.1

#### Summary

This release adds improvements based on feedback from the 0.1.0 release.

#### Features

* (MODULES-4273) Distribute CRL along with CA cert
* (MODULES-4194) add unified action for CA/CRL refresh
* (MODULES-4194) Implement CRL distribution
* (MODULES-4163) Copy cacert to localcacert on regeneration

#### Bugfixes

* (MODULES-4154) Use puppet feature to test for gem
* (MODULES-4190) Don't manage localcacert file owner/group
* (MODULES-4191) Respect casing for cert subject, issuer, AKI extension
* (MODULES-4193) sort healthcheck cmd output in ascending order
* (MODULES-4192) Use versioncmp when probing for features
* (MODULES-4194) Support Facter 1.7 confine syntax

## Experimental Release 0.1.0

#### Summary

This is a pre-production release of the certregen module.
