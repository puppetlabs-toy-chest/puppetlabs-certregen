module PuppetX
  module Certregen
    module CA
      module_function

      # Abstract API changes for CA cert signing
      #
      # @param ca [Puppet::SSL::CertificateAuthority]
      # @param hostname [String]
      # @param options [Hash<Symbol, Object>]
      def sign(ca, hostname, options)
        if Puppet::PUPPETVERSION >= "4.6.0"
          ca.sign(hostname, options)
        else
          ca.sign(hostname, options[:allow_dns_alt_names], options[:self_signing_csr])
        end
      end

      def setup
        Puppet::SSL::Host.ca_location = :only
        Puppet.settings.preferred_run_mode = "master"

        if !Puppet::SSL::CertificateAuthority.ca?
          raise "Unable to set up CA: this node is not a CA server."
        end

        if Puppet::SSL::Certificate.indirection.find('ca').nil?
          raise "Unable to set up CA: the CA certificate is not present."
        end

        Puppet::SSL::CertificateAuthority.instance
      end

      def backup
        cacert_backup_path = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
        Puppet.notice("Backing up current CA certificate to #{cacert_backup_path}")
        FileUtils.cp(Puppet[:cacert], cacert_backup_path)
      end

      def regenerate(ca, cert = Puppet::SSL::Certificate.indirection.find("ca"))
        subject_cn = cert.content.subject.to_a[0][1]

        request = Puppet::SSL::CertificateRequest.new(subject_cn)
        request.generate(ca.host.key)

        PuppetX::Certregen::CA.sign(ca, Puppet::SSL::CA_NAME,
                                    {allow_dns_alt_names: false, self_signing_csr: request})
      end
    end
  end
end
