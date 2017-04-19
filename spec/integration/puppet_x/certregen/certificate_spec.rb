require 'spec_helper'
require 'puppet_x/certregen/certificate'

RSpec.describe PuppetX::Certregen::Certificate do
  include_context "Initialize CA"

  let(:ok_certificate) do
    Puppet::SSL::CertificateAuthority.new.generate("ok")
  end

  let(:expired_certificate) do
    one_year = 60 * 60 * 24 * 365
    not_before = Time.now - one_year * 6
    not_after = Time.now - one_year
    make_certificate("expired", not_before, not_after)
  end

  let(:expiring_certificate) do
    not_before = Time.now - (60 * 60 * 24 * 365 * 4)
    not_after = Time.now + (60 * 60 * 24 * 30)
    make_certificate("expiring", not_before, not_after)
  end

  let(:short_lived_certificate) do
    not_before = Time.now - 86400
    not_after = Time.now + (60 * 5)
    make_certificate("expiring", not_before, not_after)
  end

  describe "#expiring?" do
    it "is false for nodes outside of the expiration window" do
      expect(described_class.expiring?(ok_certificate)).to eq(false)
    end

    it "is true for newly generated short lived certificates" do
      expect(described_class.expiring?(short_lived_certificate)).to eq(false)
    end

    it "is true for expired nodes" do
      expect(described_class.expiring?(expired_certificate)).to eq(true)
    end

    it "is true for nodes within the expiration window" do
      expect(described_class.expiring?(expiring_certificate)).to eq(true)
    end
  end

  describe '#expiry' do
    describe "with an expired cert" do
      subject { described_class.expiry(expired_certificate) }
      it "has a status of expired" do
        expect(subject[:status]).to eq :expired
      end

      it "includes the not after date" do
        expect(subject[:expiration_date]).to eq expired_certificate.content.not_after
      end
    end

    describe "with an expiring cert" do
      subject { described_class.expiry(expiring_certificate) }

      it "has a status of expiring" do
        expect(subject[:status]).to eq :expiring
      end

      it "includes the not after date" do
        expect(subject[:expiration_date]).to eq expiring_certificate.content.not_after
      end

      it "includes the time till expiration" do
        expect(subject[:expires_in]).to match(/29 days, 23 hours, 59 minutes/)
      end
    end

    describe "with an ok cert" do
      subject { described_class.expiry(ok_certificate) }

      it "has a status of ok" do
        expect(subject[:status]).to eq :ok
      end

      it "includes the not after date" do
        expect(subject[:expiration_date]).to eq ok_certificate.content.not_after
      end

      it "includes the time till expiration" do
        expect(subject[:expires_in]).to match(/4 years, 364 days, 23 hours, 59 minutes/)
      end
    end
  end
end
