require 'spec_helper'
require 'puppet/face/certregen'

describe Puppet::Face[:certregen, :current] do
  before(:each) do
    allow(Puppet::SSL::CertificateAuthority).to receive(:instance) { Puppet::SSL::CertificateAuthority.new }
  end

  include_context "Initialize CA"

  describe "ca action" do
    it "backs up the old CA cert and regenerates a new CA cert" do
      old_cacert_serial = Puppet::SSL::CertificateAuthority.new.host.certificate.content.serial
      described_class.ca
      new_cacert_serial = Puppet::SSL::CertificateAuthority.new.host.certificate.content.serial
      expect(old_cacert_serial).to_not eq(new_cacert_serial)
    end
  end

  describe 'healthcheck action' do
    let(:not_before) { Time.now - (60 * 60 * 24 * 365 * 4) }
    let(:not_after) { Time.now + (60 * 60 * 24 * 30) }
    it 'warns about expiring CA certificates' do
      ca = Puppet::SSL::CertificateAuthority.new
      cert = backdate_certificate(ca, ca.host.certificate, not_before, not_after)
      Puppet::SSL::Certificate.indirection.save(cert)

      allow(PuppetX::Certregen::CA).to receive(:setup).and_return Puppet::SSL::CertificateAuthority.new
      healthchecked = described_class.healthcheck
      expect(healthchecked.size).to eq(1)
      expect(healthchecked.first.digest.to_s).to eq(cert.digest.to_s)
    end

    it 'warns about expiring client certificates' do
      cert = make_certificate("expiring", not_before, not_after)
      Puppet::SSL::Certificate.indirection.save(cert)

      healthchecked = described_class.healthcheck
      expect(healthchecked.size).to eq(1)
      expect(healthchecked.first.digest.to_s).to eq(cert.digest.to_s)
    end
  end
end
