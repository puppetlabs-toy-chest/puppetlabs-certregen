RSpec.configure do |c|
  c.include PuppetlabsSpec::Files
  c.mock_with :rspec

  c.before(:each) do
    # Suppress cert fingerprint logging
    allow_any_instance_of(Puppet::SSL::CertificateAuthority).to receive(:puts)

    # remove the stub that causes puppet to believe it is
    # always being run as root.
    # See https://github.com/puppetlabs/puppetlabs_spec_helper/blob/master/lib/puppetlabs_spec_helper/module_spec_helper.rb#L29
    Puppet.features.unstub(:root?)

    Puppet[:vardir] = tmpdir('var')
    Puppet[:confdir] = tmpdir('conf')
  end

  def backdate_certificate(ca, cert, not_before, not_after)
    cert.content.not_before = not_before
    cert.content.not_after = not_after
    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(cert.content, ca.host.key.content)
    cert
  end

  def make_certificate(name, not_before, not_after)
    ca = Puppet::SSL::CertificateAuthority.new
    cert = ca.generate(name)
    backdate_certificate(ca, cert, not_before, not_after)
  end
end

RSpec.shared_context "Initialize CA" do
  # PKI generation is done by initializing a CertificateAuthority object, which has the effect of
  # applying the settings catalog, generating a RSA keypair, and generating a CA certificate.
  # Since we're regenerating the CA state between each test we need to create a new
  # CertificateAuthority object instead of using CertificateAuthority.instance, since that will
  # memoize a single instance and will not generate the ca folder structure and PKI files.
  def generate_pki
    Puppet::SSL::CertificateAuthority.new
  end

  before(:each) do
    Puppet::SSL::Host.ca_location = :only
    Puppet.settings.preferred_run_mode = "master"

    Puppet[:ca] = true
    Puppet[:ca_name] = 'Puppet CA: foo'

    generate_pki
  end
end
