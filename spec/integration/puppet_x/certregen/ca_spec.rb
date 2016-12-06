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

  describe '#sign' do
    let(:ca) { double('ca') }

    it 'uses the positional argument form when the Puppet version predates 4.6.0' do
      stub_const('Puppet::PUPPETVERSION', '4.5.0')
      expect(ca).to receive(:sign).with('hello', false, true)
      described_class.sign(ca, 'hello', allow_dns_alt_names: false, self_signing_csr: true)
    end

    it 'uses the hash argument form when the Puppet version is 4.6.0 or greater' do
      stub_const('Puppet::PUPPETVERSION', '4.8.0')
      expect(ca).to receive(:sign).with('hello', allow_dns_alt_names: false, self_signing_csr: false)
      described_class.sign(ca, 'hello', allow_dns_alt_names: false, self_signing_csr: false)
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
    it 'copies the old subject CN to the new certificate' do
      Puppet[:ca_name] = 'bar'
      described_class.regenerate(Puppet::SSL::CertificateAuthority.new)
      new_cacert = Puppet::SSL::Certificate.indirection.find("ca")
      expect(new_cacert.content.subject.to_a[0][1]).to eq 'foo'
    end
  end
end
