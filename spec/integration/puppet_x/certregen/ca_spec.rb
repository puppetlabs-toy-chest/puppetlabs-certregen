require 'spec_helper'
require 'puppet_x/certregen/ca'

RSpec.describe PuppetX::Certregen::CA do

  include_context "Initialize CA"

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
