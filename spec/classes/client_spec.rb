require 'spec_helper'

RSpec.shared_examples "managing the CRL on the client" do |setting|
  describe "when manage_crl is false" do
    let(:params) {{'manage_crl' => false}}

    it "doesn't manage the hostcrl on the client" do
      should_not contain_file(client_hostcrl)
    end
  end

  describe "when manage_crl is true" do
    let(:params) {{'manage_crl' => true}}

    it "manages the hostcrl on the client from the server '#{setting}' setting" do
      should contain_file(client_hostcrl).with(
        'ensure'  => 'present',
        'content' => Puppet.settings.setting(setting).open(&:read),
        'mode'    => '0644',
      )
    end
  end
end

RSpec.describe 'certregen::client' do
  include_context "Initialize CA"

  let(:client_localcacert) { tmpfilename('ca.pem') }
  let(:client_hostcrl) { tmpfilename('crl.pem') }

  let(:facts) do
    {
      'localcacert' => client_localcacert,
      'hostcrl'     => client_hostcrl,
      'pe_build'    => '2016.4.0',
    }
  end

  before do
    Puppet.settings.setting(:localcacert).open('w') { |f| f.write("local CA cert") }
    Puppet.settings.setting(:hostcrl).open('w') { |f| f.write("local CRL") }
  end

  describe 'when the compile master has CA ssl files' do
    before do
      Puppet.settings.setting(:cacert).open('w') { |f| f.write("CA cert") }
      Puppet.settings.setting(:cacrl).open('w') { |f| f.write("CA CRL") }
    end

    describe "managing the localcacert on the client" do
      it do
        should contain_file(client_localcacert).with(
          'ensure'  => 'present',
          'content' => Puppet.settings.setting(:cacert).open(&:read),
          'mode'    => '0644',
        )
      end
    end

    it_behaves_like "managing the CRL on the client", :cacrl
  end

  describe "when the compile master only has agent SSL files" do
    before do
      FileUtils.rm(Puppet[:cacert])
      FileUtils.rm(Puppet[:cacrl])
    end

    describe "managing the localcacert on the client" do
      it 'manages the client CA cert from the `localcacert` setting' do
        should contain_file(client_localcacert).with(
          'ensure'  => 'present',
          'content' => Puppet.settings.setting(:localcacert).open(&:read),
          'mode'    => '0644',
        )
      end
    end

    it_behaves_like "managing the CRL on the client", :hostcrl
  end
end
