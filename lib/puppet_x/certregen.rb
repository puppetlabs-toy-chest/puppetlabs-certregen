require 'puppet/ssl/host'
require 'fileutils'

module PuppetX
  module Certregen

    module_function

    def setup_ca
      Puppet::SSL::Host.ca_location = :only
      Puppet.settings.preferred_run_mode = "master"

      raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
      unless ca = Puppet::SSL::CertificateAuthority.instance
        raise "Unable to fetch the CA"
      end
      ca
    end

    def backup_cacert
      cacert_backup_path = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
      Puppet.notice("Backing up current CA certificate to #{cacert_backup_path}")
      FileUtils.cp(Puppet[:cacert], cacert_backup_path)
    end

    def regenerate_cacert(ca, cert = Puppet::SSL::Certificate.indirection.find("ca"))
      subject_cn = cert.content.subject.to_a[0][1]

      request = Puppet::SSL::CertificateRequest.new(subject_cn)
      request.generate(ca.host.key)

      if Puppet::PUPPETVERSION >= "4.6.0"
        ca.sign(Puppet::SSL::CA_NAME, {allow_dns_alt_names: false, self_signing_csr: request})
      else
        ca.sign(Puppet::SSL::CA_NAME, false, request)
      end
    end
  end
end
