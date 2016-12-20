require 'spec_helper'
require 'puppet_x/certregen/crl'

RSpec.describe PuppetX::Certregen::CRL do
  include_context "Initialize CA"

  describe '.refresh' do
    def normalize_time(t)
      t.utc.round
    end

    let(:stub_time) { normalize_time(Time.now + 60 * 60 * 24 * 365) }
    let(:oldcrl) { @oldcrl }

    before do
      @oldcrl = Puppet::SSL::CertificateRevocationList.indirection.find("ca")
      allow(Time).to receive(:now).and_return stub_time
      described_class.refresh(Puppet::SSL::CertificateAuthority.new)
    end

    subject { Puppet::SSL::CertificateRevocationList.indirection.find('ca') }

    it 'updates the lastUpdate field' do
      last_update = normalize_time(subject.content.last_update.utc)
      expect(last_update).to eq normalize_time(stub_time - 1)
    end

    it 'updates the nextUpdate field' do
      next_update = normalize_time(subject.content.next_update.utc)
      expect(next_update).to eq normalize_time(stub_time + described_class::FIVE_YEARS)
    end

    def crl_number(crl)
      crl.content.extensions.find { |ext| ext.oid == 'crlNumber' }.value
    end

    it "increments the CRL number" do
      newcrl = Puppet::SSL::CertificateRevocationList.from_instance(
        OpenSSL::X509::CRL.new(File.read(Puppet[:cacrl])), 'ca')

      old_crl_number = crl_number(oldcrl).to_i
      new_crl_number = crl_number(newcrl).to_i
      expect(new_crl_number).to eq old_crl_number + 1
    end

    it 'copies the cacrl to the hostcrl' do
      cacrl = Puppet::SSL::CertificateRevocationList.from_instance(
                               OpenSSL::X509::CRL.new(File.read(Puppet[:cacrl])), 'ca')
      hostcrl = Puppet::SSL::CertificateRevocationList.from_instance(
                               OpenSSL::X509::CRL.new(File.read(Puppet[:hostcrl])), 'ca')
      expect(crl_number(cacrl)).to eq crl_number(hostcrl)
    end
  end
end
