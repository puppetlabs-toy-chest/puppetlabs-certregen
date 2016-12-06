require 'spec_helper'
require 'puppet_x/certregen/ca'

RSpec.describe PuppetX::Certregen::CA do

  include_context "Initialize CA"

  describe "#setup" do
    it "errors out when the node is not a CA" do
      Puppet[:ca] = false
      expect {
        described_class.setup
      }.to raise_error(RuntimeError, "Unable to set up CA: this node is not a CA server.")
    end

    it "errors out when the node does not have a signed CA certificate" do
      FileUtils.rm(Puppet[:cacert])
      expect {
        described_class.setup
      }.to raise_error(RuntimeError, "Unable to set up CA: the CA certificate is not present.")
    end
  end

  describe '#backup_cacert' do
    it 'backs up the CA cert based on the current timestamp' do
      now = Time.now
      expect(Time).to receive(:now).at_least(:once).and_return now
      described_class.backup
      backup = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
      expect(File.read(backup)).to eq(File.read(Puppet[:cacert]))
    end
  end

  describe '#regenerate_cacert' do
    it 'generates a certificate with a different serial number' do
      old_serial = Puppet::SSL::CertificateAuthority.new.host.certificate.content.serial
      described_class.regenerate(Puppet::SSL::CertificateAuthority.new)
      new_serial = Puppet::SSL::Certificate.indirection.find("ca").content.serial
      expect(old_serial).to_not eq new_serial
    end

    it 'copies the old subject CN to the new certificate' do
      Puppet[:ca_name] = 'bar'
      described_class.regenerate(Puppet::SSL::CertificateAuthority.new)
      new_cacert = Puppet::SSL::Certificate.indirection.find("ca")
      expect(new_cacert.content.subject.to_a[0][1]).to eq 'foo'
    end

    it 'copies the cacert to the localcacert' do
      described_class.regenerate(Puppet::SSL::CertificateAuthority.new)
      cacert = Puppet::SSL::Certificate.from_instance(
                                       OpenSSL::X509::Certificate.new(File.read(Puppet[:cacert])))
      localcacert = Puppet::SSL::Certificate.from_instance(
                                       OpenSSL::X509::Certificate.new(File.read(Puppet[:localcacert])))
      expect(cacert.content.serial).to eq localcacert.content.serial
    end
  end
end
