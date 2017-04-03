require 'spec_helper'
require 'puppet/face/certregen'

describe Puppet::Face[:certregen, :current] do
  before(:each) do
    allow(Puppet::SSL::CertificateAuthority).to receive(:instance) { Puppet::SSL::CertificateAuthority.new }
  end

  include_context "Initialize CA"

  describe "ca action" do
    it "invokes the cacert and crl actions" do
      expect(described_class).to receive(:cacert).with(ca_serial: "01")
      expect(described_class).to receive(:crl)
      described_class.ca(ca_serial: "01")
    end
  end

  describe "cacert action" do
    it "raises an error when the ca_serial option is not provided" do
      expect {
        described_class.ca
      }.to raise_error(RuntimeError, /The serial number of the CA certificate to rotate must be provided/)
    end

    it "raises an error when the ca_serial option is not provided" do
      expect {
        described_class.ca(ca_serial: "02")
      }.to raise_error(RuntimeError, /The serial number of the current CA certificate \(01\) does not match the serial number/)
    end

    it "backs up the old CA cert and regenerates a new CA cert" do
      old_cacert_serial = Puppet::SSL::CertificateAuthority.new.host.certificate.content.serial
      described_class.ca(ca_serial: "01")
      new_cacert_serial = Puppet::SSL::CertificateAuthority.new.host.certificate.content.serial
      expect(old_cacert_serial).to_not eq(new_cacert_serial)
    end

    it "returns the new CA certificate" do
      returned_cacert = described_class.ca(ca_serial: "01").first
      new_cacert = Puppet::SSL::CertificateAuthority.new.host.certificate.content
      expect(returned_cacert.content.serial).to eq new_cacert.serial
      expect(returned_cacert.content.not_after).to eq new_cacert.not_after
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

    it 'orders certificates from shortest expiry to longest expiry' do
      Puppet::SSL::Certificate.indirection.save(make_certificate("first", not_before, not_after))
      Puppet::SSL::Certificate.indirection.save(make_certificate("last", not_before + 1, not_after + 1))

      expect(described_class.healthcheck.map(&:name)).to eq %w[first last]
    end
  end
end
