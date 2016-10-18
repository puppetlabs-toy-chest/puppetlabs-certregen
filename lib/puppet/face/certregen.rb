require 'puppet/face'
require 'puppet_x/certregen'

Puppet::Face.define(:certregen, '0.1.0') do
  summary "Regenerate the Puppet CA and client certificates"

  action(:ca) do
    summary "Regenerate the Puppet CA certificate"

    when_invoked do |opts|
      ca = setup_ca
      PuppetX::Certregen.backup_cacert
      PuppetX::Certregen.regenerate_cacert(ca)
      nil
    end
  end

  action(:healthcheck) do
    summary "Check for expiring client certificates"
    when_invoked do |opts|
      ca = setup_ca

      one_day_in_seconds = 60 * 60 * 24
      six_months_in_seconds = one_day_in_seconds * 180

      ca.list_certificates.each do |cert|

        expiry = cert.content.not_after - Time.now
        if expiry < six_months_in_seconds
          Puppet.warning "Cert #{cert.name} (serial #{cert.content.serial}) expires in #{(expiry / one_day_in_seconds).to_i} day(s)"
        end
      end
      nil
    end
  end
end
