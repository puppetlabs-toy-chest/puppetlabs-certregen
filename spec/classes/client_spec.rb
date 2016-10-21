require 'spec_helper'

RSpec.describe 'certregen::client' do
  include_context "Initialize CA"

  let(:client_localcacert) { tmpfilename('ca.pem') }
  let(:facts) {{'localcacert' => client_localcacert }}

  before do
    Puppet.settings.setting(:cacert).open('w') { |f| f.write("CA cert") }
    Puppet.settings.setting(:localcacert).open('w') { |f| f.write("local CA cert") }
  end

  describe 'when the compile master is the CA' do
    before { Puppet[:ca] = true }

    it do
      should contain_file(client_localcacert).with(
        'ensure'  => 'present',
        'content' => Puppet.settings.setting(:cacert).open(&:read),
        'owner'   => '0',
        'group'   => '0',
        'mode'    => '0644',
      )
    end
  end

  describe 'when the compile master is not the CA' do
    before { Puppet[:ca] = false }

    it 'manages the client CA cert from the `localcacert` setting' do
      should contain_file(client_localcacert).with(
        'ensure'  => 'present',
        'content' => Puppet.settings.setting(:localcacert).open(&:read),
        'owner'   => '0',
        'group'   => '0',
        'mode'    => '0644',
      )
    end
  end
end
