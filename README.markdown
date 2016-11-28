#Certregen

####Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Installing](#installing)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)

##Overview

The certregen module regenerates and distributes expiring certificates.

##Module Description

The certregen module regenerates expiring CA certificates while maintaining the validity of signed certificates in an existing PKI, and provides information about certificate expiration.

##Installing

1. Clone this repository to `/etc/puppetlabs/code/modules` (or any directory in your master's modulepath), with the directory name `certregen`

~~~
git clone https://github.com/puppetlabs/puppetlabs-certregen.git /etc/puppetlabs/code/modules/certregen
~~~

2. Run

~~~
puppet plugin download
~~~

##Usage

Regenerating a expiring Puppet CA certificate is a two step process of generating a new CA certificate, and then distributing the new certificate.

###Quick start

  1. Run `puppet certregen ca --ca_serial 01`
  2. Add the `certregen::client` class to all nodes (in PE, you’ll probably want to use the “PE Agent” group)
  3. Run Puppet on the CA server
  4. Run Puppet on the compile masters (if present)
  5. Run Puppet on all agent only nodes

###CA certificate regeneration

CA certificate regeneration is handled by the `puppet certregen ca` action. The regenerated CA certificate will have the same subject as the old CA certificate but will have new notBefore and notAfter dates and a new serial number.

~~~
[root@pe-201621-master ~]# puppet certregen ca --ca_serial 01
Notice: Backing up current CA certificate to /etc/puppetlabs/puppet/ssl/ca/ca_crt.1477348467.pem
Notice: Signed certificate request for ca
~~~

Note that the `--ca_serial` argument must always be given to make sure that the CA certificate is not unexpectedly rotated by an errant command.

Once the CA certificate has been rotated the `certregen::client` class should be included on all nodes to distribute the new certificate. If a master of master in use the compile masters will need to run Puppet and get a copy of the CA certificate before they can distribute the CA certificate to their clients.

##Reference

###Faces

####puppet certregen ca

Regenerate the CA certificate with the subject of the old CA certificate and updated notBefore and notAfter dates.

####puppet certregen healthcheck

Check all signed certificates (including the CA certificate) for certificates that are expired or nearing expiry.

**Examples**:

~~~
[root@pe-201621-master vagrant]# puppet certregen healthcheck
"foo.com" (SHA256) 07:2F:61:B4:FB:B3:05:75:9D:45:D1:A8:B1:69:0F:D0:EB:C9:27:03:4E:F8:DD:4A:59:AE:DF:EF:8E:11:74:69
  Status: expiring
  Expiration date: 2016-11-02 19:52:59 UTC
  Expires in: 4 minutes, 19 seconds
~~~

####puppet certregen redistribute

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


###Classes

####Public Classes

  * `certregen::client`: Rotate the CA certificate on Puppet agents.

##Limitations

The certregen module is designed to rotate an expiring CA certificate and reuse the CA key pair. Because the keypair is reused this module is unsuitable for rotating a CA certificate when the CA private key has been compromised.

##Development

Puppet Labs modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. We can’t access the huge number of platforms and myriad of hardware, software, and deployment configurations that Puppet is intended to serve.

We want to keep it as easy as possible to contribute changes so that our modules work in your environment. There are a few guidelines that we need contributors to follow so that we can have a chance of keeping on top of things.

For more information, see our [module contribution guide.](https://docs.puppetlabs.com/forge/contributing.html)
