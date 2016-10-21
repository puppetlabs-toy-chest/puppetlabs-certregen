require 'puppet/face'
require 'puppet_x/certregen/ca'
require 'puppet_x/certregen/certificate'

Puppet::Face.define(:certregen, '0.1.0') do
  summary "Regenerate the Puppet CA and client certificates"

  action(:ca) do
    summary "Regenerate the Puppet CA certificate"

    when_invoked do |opts|
      ca = PuppetX::Certregen::CA.setup
      PuppetX::Certregen::CA.backup
      PuppetX::Certregen::CA.regenerate(ca)
      nil
    end
  end

  action(:healthcheck) do
    summary "Check for expiring certificates"

    option('--all') do
      summary 'Report certificate expiry for all nodes'
    end

    when_invoked do |opts|
      certs = []
      ca = PuppetX::Certregen::CA.setup
      cacert = ca.host.certificate
      certs << cacert if (opts[:all] || PuppetX::Certregen::Certificate.expiring?(cacert))

      certs.concat(ca.list_certificates.select do |cert|
        opts[:all] || PuppetX::Certregen::Certificate.expiring?(cert)
      end.to_a)

      certs.sort { |a, b| b.content.not_after <=> a.content.not_after }
    end

    when_rendering :console do |certs|
      certs.map do |cert|
        str = "#{cert.name.inspect} #{cert.digest.to_s}\n"
        PuppetX::Certregen::Certificate.expiry(cert).each do |row|
          str << "  #{row[0]}: #{row[1]}\n"
        end
        str
      end
    end
  end
end
