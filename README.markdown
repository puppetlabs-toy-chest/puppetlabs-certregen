# Certregen

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Installing](#installing)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)

## Overview

The certregen module can painlessly refresh a certificate authority (CA) that's about to expire. It can also revive a CA that has already expired.

## Module Description

This module is for regenerating and redistributing Puppet CA certificates and refreshing CRLs, without invalidating certificates signed by the original CA.

A Puppet deployment's CA certificate is only valid for a limited time (usually five years), after which it expires. When a CA expires, Puppet's services will no longer accept any certificates signed by that CA, and your Puppet infrastructure will immediately stop working.

If your Puppet infrastructure has been in place for almost five years, you should:

* Check to see if your CA is expiring soon.

If your CA is expiring soon (or it's already expired and Puppet has stopped working), you should:

* Generate a new CA certificate using the existing CA keypair. This will also automatically update the expiration date of the certificate revocation list (CRL).
* Distribute the new CA cert and CRL to every node in your Puppet infrastructure.

The certregen module can help you with all of these tasks.

> **Note:** This module is NOT currently designed for the following tasks:
>
> * Re-keying and replacing a CA that has become untrustworthy (by a private key compromise or by a vulnerability like Heartbleed or the old `certdnsnames` bug).
> * Refreshing normal node certificates that are nearing expiration.
>
> For the time being, you're on your own for these.

## Installing

If you manage your code with a Puppetfile, add the following line, replacing `<VERSION>` with the version you want to use:

```
mod 'puppetlabs-certregen', '<VERSION>'
```

To install manually, run:

```
puppet module install puppetlabs-certregen
```

## Usage

The certregen module can help you with four main tasks:

* Check whether any certificates (including the CA) are expired or nearing their expiration date.
* Refresh and redistribute a CA that hasn't yet expired, in a working Puppet deployment.
* Refresh and redistribute a CRL that hasn't yet expired, in a working Puppet deployment.
* Revive and redistribute an expired CA and CRL, in a Puppet deployment that has stopped working.

### Check for nearly-expired (or expired) certificates

The `healthcheck` action can show you which certificates are expiring soon, as well as any that have already expired. The most important certificate is your CA cert --- if it is almost expired, you must refresh it soon.

1. **On your Puppet CA server,** run `sudo puppet certregen healthcheck`.

   This finds any certificates with less than 10% of their lifetime remaining (plus any that have already expired), and lists their certname, fingerprint, remaining lifetime, and expiration date. (If no certs are near expiration, the output is blank.)

   ```
   [root@pe-201621-master vagrant]# puppet certregen healthcheck
   "foo.com" (SHA256) 07:2F:61:B4:FB:B3:05:75:9D:45:D1:A8:B1:69:0F:D0:EB:C9:27:03:4E:F8:DD:4A:59:AE:DF:EF:8E:11:74:69
     Status: expiring
     Expiration date: 2016-11-02 19:52:59 UTC
     Expires in: 4 minutes, 19 seconds
   ```

2. Search the `healthcheck` output for a cert named `"ca"`, which is your CA. **If "ca" is expiring or expired, you must refresh it or revive it as soon as possible.** See the tasks below for more details.

### Refresh a CA that's expiring soon

[ca_ttl]: https://docs.puppet.com/puppet/latest/reference/configuration.html#cattl
[main manifest]: https://docs.puppet.com/puppet/latest/reference/dirs_manifest.html

To refresh an expiring CA, you must:

* Regenerate the CA certificate with `puppet certregen ca`.
* Distribute the new CA with the `certregen::client` class.

Before you begin, check to make sure your CA really needs to be refreshed (see above).

1. **On your Puppet CA server,** run `sudo puppet certregen ca`.

   **This will result in an error,** which is normal: since this action replaces your CA cert, it has an extra layer of protection. The error should look something like this:

   ```
   Error: The serial number of the CA certificate to rotate must be provided. If you are sure that you want to rotate the CA certificate, rerun this command with --ca_serial 03
   ```

2. In the error message, find and remember the `--ca_serial <NUMBER>` option.
3. Run `sudo puppet certregen ca --ca_serial <NUMBER>`, using the number from the error message.

   By default, this gives the new CA a lifetime of five years. If you wish to set a non-default lifetime, you can add `--ca_ttl <DURATION>`. See [the docs on the ca_ttl setting][ca_ttl] for details.

   When you regenerate the CA certificate, the CRL will be refreshed at the same time with a new expiration of five years as well.

   At this point:

   * The CA certificate _on your CA server_ has been replaced with a new one. The new CA uses the same keypair, subject, issuer, and subject key identifier as the old one; in practical terms, this means it is a seamless replacement for the old CA.
   * The CRL _on your CA server_ has been updated with a new expiration date, but is otherwise unchanged.
   * Your Puppet nodes are still using the old CA and CRL.
4. **In your [main manifest][] directory,** add a new manifest file called `ca.pp`. In that file, add this line:

   ``` puppet
   include certregen::client
   ```

   > **Note:** You must do this in **every** active environment, so that **every** node receives this class in its catalog. You must also ensure that the certregen module is installed in every active environment.
   >
   > If you have a prohibitively large number of environments... contact us, because we're still developing this module and soliciting feedback on it.
5. If your deployment has multiple compile masters, make sure each one completes a Puppet run against the CA server.
6. Ensure that Puppet runs at least once on every other node in your deployment.
7. On any Puppet infrastructure nodes (Puppet Server, PuppetDB, PE console), restart all Puppet-related services. The exact services to restart will depend on your version of PE or open source Puppet.

At this point, the new CA and CRL is fully distributed and you're good for another five years.

### Revive a CA that's already expired

[ssldir]: https://docs.puppet.com/puppet/latest/reference/dirs_ssldir.html

If your CA has expired, Puppet has already stopped working, and recovering will take some extra work. You must:

* Regenerate the CA certificate with `puppet certregen ca`.
* Distribute the new CA to Linux nodes with `puppet certregen redistribute`.
* Manually distribute the new CA to Windows and non-Linux \*nix nodes.

Before you begin:

* Check to make sure your CA has really expired (see above).
* If you wish to automatically distribute the new CA cert, ensure that:
    * The Puppet CA server is also a PuppetDB server.
    * Your Linux nodes have a user account which can log in with an SSH key and run `sudo` commands without a password.

1. **On your Puppet CA server,** run `sudo puppet certregen ca`.

   **This will result in an error,** which is normal: since this action replaces your CA cert, it has an extra layer of protection. The error should look something like this:

   ```
   Error: The serial number of the CA certificate to rotate must be provided. If you are sure that you want to rotate the CA certificate, rerun this command with --ca_serial 03
   ```

2. In the error message, find and remember the `--ca_serial <NUMBER>` option.
3. Run `sudo puppet certregen ca --ca_serial <NUMBER>`, using the number from the error message.

   By default, this gives the new CA a lifetime of five years. If you wish to set a non-default lifetime, you can add `--ca_ttl <DURATION>`. See [the docs on the ca_ttl setting][ca_ttl] for details.

   When you regenerate the CA certificate, the CRL will be refreshed at the same time with a new expiration of five years as well.

   At this point:

   * The CA certificate _on your CA server_ has been replaced with a new one. The new CA uses the same keypair, subject, issuer, and subject key identifier as the old one; in practical terms, this means it is a seamless replacement for the old CA.
   * The CRL _on your CA server_ has been updated with a new expiration date, but is otherwise unchanged.
   * Your Puppet nodes still have the old CA, and Puppet is still non-functional.

4. Use `puppet certregen redistribute` to automatically distribute the CA certificate and CRL to as many Linux nodes as possible. If you don't meet the prerequisites for this (see above), move on to the next step and manually copy the new CA cert to all nodes.

   1. Ensure that the CA server has an SSH private key that can log into your affected nodes. If this key is not usually present on this server, copy it over temporarily.
   2. Run `/opt/puppetlabs/puppet/bin/gem install chloride`. This SSH helper gem is required by the `certregen redistribute` action.
   3. Run `puppet certregen redistribute --username <USER> --ssh_key_file <PATH TO KEY>`, replacing the placeholders with your SSH key and username.

   This extracts a list of node hostnames from PuppetDB's database, then copy the new CA cert to each node using SSH. When finished, it lists which nodes were successful and which ones failed.

   ```
   [root@pe-201640-master vagrant]# puppet certregen redistribute --username vagrant --ssh_key_file /vagrant/id_rsa

   {
     "succeeded": [
       "pe-201640-agent0.puppetdebug.vlan",
       "pe-201640-agent1.puppetdebug.vlan",
       "pe-201640-agent3.puppetdebug.vlan"
       "pe-201640-agent2.puppetdebug.vlan",
       "pe-201640-agent4.puppetdebug.vlan",
       "pe-201640-master.puppetdebug.vlan"
     ],
     "failed": [
     ]
   }
   ```
5. Manually copy the new CA certificate to any non-Linux nodes and any nodes where automatic distribution failed.

   * The source file is on your CA server, at `/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem`.
   * Copy it to `<SSLDIR>/certs/ca.pem` on every node. The default ssldir is `/etc/puppetlabs/puppet/ssl` on \*nix, and `%PROGRAMDATA%\PuppetLabs\puppet\etc` on Windows. See [the ssldir docs][ssldir] for the full details.
   * If you have any other services that use Puppet's PKI (like MCollective, for example), you must update the CA cert for them as well.

6. Manually copy the updated CRL to any non-Linux nodes and any nodes where automatic distribution failed.

   * The source file is on your CA server, at `/etc/puppetlabs/puppet/ssl/ca/ca_crl.pem`.
   * Copy it to `<SSLDIR>/crl.pem` on every node. The default ssldir is `/etc/puppetlabs/puppet/ssl` on \*nix, and `%PROGRAMDATA%\PuppetLabs\puppet\etc` on Windows. See [the ssldir docs][ssldir] for the full details.
   * If you have any other services that use Puppet's PKI (like MCollective, for example) and uses the Puppet CRL, you must update the CRL for them as well.

7. On any Puppet infrastructure nodes (Puppet Server, PuppetDB, PE console), restart all Puppet-related services. The exact services to restart will depend on your version of PE or open source Puppet.

At this point, the new CA and CRL is fully distributed and you're good for another five years.

## Reference

### Concepts

Puppet's security is based on a PKI using X.509 certificates. If you're only partially familiar with these concepts, [we've written an introductory primer](https://docs.puppet.com/background/ssl/) about them.

The certregen module's `puppet certregen ca` action creates a new self-signed CA cert using the same keypair as the prior self-signed CA. The new CA has the same:

* Keypair.
* Subject.
* Issuer.
* X509v3 Subject Key Identifier (the fingerprint of the public key).

The new CA has a different:

* Authority Key Identifier (just the serial number, since it's self-signed).
* Validity period (the point of the whole exercise).
* Signature (since we changed the serial number and validity period).

Since Puppet's services (and other services that use Puppet's PKI) validate certs by trusting a self-signed CA and comparing its public key to the signatures and Authority Key Identifiers of the certs it has issued, it's possible to issue a new self-signed CA based on a prior keypair without invalidating any certs issued by the old CA. Once you've done that, it's just a matter of delivering the new CA cert to every participant in the PKI.

### Faces

#### puppet certregen ca

Regenerate the CA certificate with the subject of the old CA certificate and updated notBefore and notAfter dates, and update the CRL with a nextUpdate field of 5 years from the present date.

This command combines the behaviors of the `puppet certregean cacert` and `puppet certregen crl` commands and is the preferred method of regenerating your CA.

#### puppet certregen healthcheck

Check all signed certificates (including the CA certificate) for certificates that are expired or nearing expiry.

**Examples**:

~~~
[root@pe-201621-master vagrant]# puppet certregen healthcheck
"foo.com" (SHA256) 07:2F:61:B4:FB:B3:05:75:9D:45:D1:A8:B1:69:0F:D0:EB:C9:27:03:4E:F8:DD:4A:59:AE:DF:EF:8E:11:74:69
  Status: expiring
  Expiration date: 2016-11-02 19:52:59 UTC
  Expires in: 4 minutes, 19 seconds
~~~

#### puppet certregen cacert

Regenerate the CA certificate with the subject of the old CA certificate and updated notBefore and notAfter dates.

#### puppet certregen crl

Update the CRL with a nextUpdate field of 5 years from the present date.

CRLs don't usually expire, since their expiration date is normally updated whenever a certificate is revoked. But in rare cases, like when no certificates have been revoked in five years, they can expire and cause problems.

#### puppet certregen redistribute

Copy a regenerated Puppet CA certificate to all active nodes in PuppetDB in case the CA cert has already expired. This command must be run on the CA server and requires that the PostgreSQL server that PuppetDB uses is also located on the current node.

~~~
[root@pe-201640-master vagrant]# puppet certregen redistribute --username vagrant --ssh_key_file /vagrant/id_rsa

{
  "succeeded": [
    "pe-201640-agent0.puppetdebug.vlan",
    "pe-201640-agent1.puppetdebug.vlan",
    "pe-201640-agent3.puppetdebug.vlan"
    "pe-201640-agent2.puppetdebug.vlan",
    "pe-201640-agent4.puppetdebug.vlan",
    "pe-201640-master.puppetdebug.vlan"
  ],
  "failed": [
  ]
}
~~~

This subcommand depends on the `chloride` gem, which is not included with this Puppet face. In order to use this subcommand you must manually install it with the `gem` command provided via the Puppet agent installer.


### Classes

#### Public Classes

  * `certregen::client`: Rotate the CA certificate and CRL on Puppet agents.

## Limitations

The certregen module is designed to rotate an expiring CA certificate and reuse the CA key pair. Because the keypair is reused this module is unsuitable for rotating a CA certificate when the CA private key has been compromised.

## Development

Puppet Labs modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. We can’t access the huge number of platforms and myriad of hardware, software, and deployment configurations that Puppet is intended to serve.

We want to keep it as easy as possible to contribute changes so that our modules work in your environment. There are a few guidelines that we need contributors to follow so that we can have a chance of keeping on top of things.

For more information, see our [module contribution guide.](https://docs.puppetlabs.com/forge/contributing.html)
