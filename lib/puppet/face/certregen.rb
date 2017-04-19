require 'puppet/face'
require 'puppet_x/certregen/ca'
require 'puppet_x/certregen/certificate'
require 'puppet_x/certregen/crl'
require 'puppet/feature/chloride'

Puppet::Face.define(:certregen, '0.1.0') do
  copyright "Puppet", 2016
  summary "Regenerate the Puppet CA and client certificates"

  description <<-EOT
    This subcommand provides tools for monitoring the health of the Puppet CA, regenerating
    expiring CA certificates, and remediation for expired CA certificates.
  EOT

  action(:ca) do
    summary "Refresh the Puppet CA certificate and CRL"

    option('--ca_serial SERIAL') do
      summary 'The serial number (in hexadecimal) of the CA to rotate.'
    end

    when_invoked do |opts|
      cert = Puppet::Face[:certregen, :current].cacert(:ca_serial => opts[:ca_serial])
      crl = Puppet::Face[:certregen, :current].crl()
      [cert, crl]
    end

    when_rendering :console do |(cert, crl)|
      "CA expiration is now #{cert.content.not_after}\n" + \
      "CRL next update is now #{crl.content.next_update}"
    end
  end

  action(:cacert) do
    summary "Regenerate the Puppet CA certificate"

    description <<-EOT
      This subcommand generates a new CA certificate that can replace the existing CA certificate.
      The new CA certificate uses the same subject as the current CA certificate and reuses the
      key pair associated with the current CA certificate, so all certificates signed by the old
      CA certificate will remain valid.
    EOT

    option('--ca_serial SERIAL') do
      summary 'The serial number (in hexadecimal) of the CA to rotate.'
    end

    when_invoked do |opts|
      ca = PuppetX::Certregen::CA.setup

      current_ca_serial = ca.host.certificate.content.serial.to_s(16)
      if opts[:ca_serial].nil?
        raise "The serial number of the CA certificate to rotate must be provided. If you " \
          "are sure that you want to rotate the CA certificate, rerun this command with " \
          "--ca_serial #{current_ca_serial}"
      elsif opts[:ca_serial] != current_ca_serial
        raise "The serial number of the current CA certificate (#{current_ca_serial}) "\
          "does not match the serial number given on the command line (#{opts[:ca_serial]}). "\
          "If you are sure that you want to rotate the CA certificate, rerun this command with "\
          "--ca_serial #{current_ca_serial}"
      end

      PuppetX::Certregen::CA.backup
      PuppetX::Certregen::CA.regenerate(ca)
      Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME)
    end

    when_rendering(:console) do |cert|
      "CA expiration is now #{cert.content.not_after}"
    end
  end

  action(:crl) do
    summary 'Update the lastUpdate and nextUpdate field for the CA CRL'

    when_invoked do |opts|
      ca = PuppetX::Certregen::CA.setup
      PuppetX::Certregen::CRL.refresh(ca)
    end

    when_rendering(:console) do |crl|
      "CRL next update is now #{crl.content.next_update}"
    end
  end

  action(:healthcheck) do
    summary "Check for expiring certificates"

    description <<-EOT
      This subcommand checks for certificates that are nearing or past expiration.
    EOT

    option('--all') do
      summary "Report certificate expiry for all nodes, including nodes that aren't near expiration."
    end

    when_invoked do |opts|
      ca = PuppetX::Certregen::CA.setup

      certs = Puppet::SSL::Certificate.indirection.search('*').select do |cert|
        opts[:all] || PuppetX::Certregen::Certificate.expiring?(cert)
      end

      cacert = ca.host.certificate
      certs << cacert if (opts[:all] || PuppetX::Certregen::Certificate.expiring?(cacert))

      certs.sort { |a, b| a.content.not_after <=> b.content.not_after }
    end

    when_rendering :console do |certs|
      if certs.empty?
        "No certificates are approaching expiration."
      else
        certs.map do |cert|
          str = "#{cert.name.inspect} #{cert.digest.to_s}\n"
          expiry = PuppetX::Certregen::Certificate.expiry(cert)
          str << "Status: #{expiry[:status]}\n"
          str << "Expiration date: #{expiry[:expiration_date]}\n"
          if expiry[:expires_in]
            str << "Expires in: #{expiry[:expires_in]}\n"
          end
          str
        end
      end
    end

    when_rendering :pson do |certs|
      certs.map do |cert|
        {
          :name => cert.name,
          :digest => cert.digest.to_s,
          :expiry => PuppetX::Certregen::Certificate.expiry(cert)
        }
      end
    end

    when_rendering :yaml do |certs|
      certs.map do |cert|
        {
          :name => cert.name,
          :digest => cert.digest.to_s,
          :expiry => PuppetX::Certregen::Certificate.expiry(cert)
        }
      end
    end
  end

  action(:redistribute) do
    summary "Redistribute the regenerated CA certificate and CRL to nodes in PuppetDB"

    description <<-EOT
      Redistribute the regenerated CA certificate and CRL to active nodes in PuppetDB. This command is
      only necessary if the CA certificate is expired and a new CA certificate needs to be manually
      distributed via SSH.

      This subcommand depends on the `chloride` gem, which is not included with this Puppet face.

      Distributing the CA certificate via SSH requires either a private ssh key (given by the
      `--ssh_key_file` flag) or entering the password when prompted. If password auth is used,
      the `highline` gem should be installed so that the entered password is not echoed to the
      terminal.
    EOT

    option('--username USER') do
      summary "The username to use when logging into the remote machine"
    end

    option('--ssh_key_file FILE') do
      summary "The SSH key file to use for authentication"
      default_to { "~/.ssh/id_rsa" }
    end

    when_invoked do |opts|
      unless Puppet.features.chloride?
        raise "Unable to distribute CA certificate: the chloride gem is not available."
      end

      config = {}

      config.merge!(username: opts[:username]) if opts[:username]
      config.merge!(ssh_key_file: File.expand_path(opts[:ssh_key_file])) if opts[:ssh_key_file]

      ca = PuppetX::Certregen::CA.setup
      cacert = ca.host.certificate
      if PuppetX::Certregen::Certificate.expiring?(cacert)
        Puppet.err "Refusing to distribute CA certificate: certificate is pending expiration."
        exit 1
      end

      rv = {succeeded: [], failed: []}
      PuppetX::Certregen::CA.certnames.each do |certname|
        begin
          PuppetX::Certregen::CA.distribute(certname, config)
          rv[:succeeded] << certname
        rescue => e
          Puppet.log_exception(e)
          rv[:failed] << certname
        end
      end

      rv
    end
  end
end
