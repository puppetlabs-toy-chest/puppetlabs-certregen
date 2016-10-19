require 'spec_helper'
require 'puppet_x/certregen'

context PuppetX::Certregen do

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
    Puppet[:vardir] = tmpdir('var')
    Puppet[:ssldir] = tmpdir('ssl')
    Puppet[:user] = ENV['USER']
    Puppet[:ca_name] = 'foo'
    generate_pki
  end

  describe '#backup_cacert' do
    it 'backs up the CA cert based on the current timestamp' do
      now = Time.now
      expect(Time).to receive(:now).at_least(:once).and_return now
      PuppetX::Certregen.backup_cacert
      backup = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
      expect(File.read(backup)).to eq(File.read(Puppet[:cacert]))
    end
  end

  describe '#regenerate_cacert' do
    it 'copies the old subject CN to the new certificate' do
      Puppet[:ca_name] = 'bar'
      PuppetX::Certregen.regenerate_cacert(Puppet::SSL::CertificateAuthority.new)
      new_cacert = Puppet::SSL::Certificate.indirection.find("ca")
      expect(new_cacert.content.subject.to_a[0][1]).to eq 'foo'
    end
  end
end
