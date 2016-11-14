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

###CA certificate regeneration

CA certificate regeneration is handled by the `puppet certregen ca` action. The regenerated CA certificate will have the same subject as the old CA certificate but will have new notBefore and notAfter dates and a new serial number.

~~~
[root@pe-201621-master ~]# puppet certregen ca
Notice: Backing up current CA certificate to /etc/puppetlabs/puppet/ssl/ca/ca_crt.1477348467.pem
Notice: Signed certificate request for ca
~~~

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


###Classes

####Public Classes

  * `certregen::client`: Rotate the CA certificate on Puppet agents.

##Limitations

The certregen module is designed to rotate an expiring CA certificate and reuse the CA key pair. Because the keypair is reused this module is unsuitable for rotating a CA certificate when the CA private key has been compromised.

##Development

Puppet Labs modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. We can’t access the huge number of platforms and myriad of hardware, software, and deployment configurations that Puppet is intended to serve.

We want to keep it as easy as possible to contribute changes so that our modules work in your environment. There are a few guidelines that we need contributors to follow so that we can have a chance of keeping on top of things.

For more information, see our [module contribution guide.](https://docs.puppetlabs.com/forge/contributing.html)
