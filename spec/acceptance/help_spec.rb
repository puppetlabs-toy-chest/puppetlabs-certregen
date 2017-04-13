require 'spec_helper_acceptance'

describe "pupper help certregen" do
  # NOTE: MODULES-4733 certregen is not currently compatible with ruby < 1.9
  ruby_ver = 0
  on(default, 'ruby --version') do |result|
    m = /\d+\.\d+\.\d+/.match(result.stdout)
    ruby_ver = m[0] if m
  end
  unless version_is_less(ruby_ver, '1.9') then
    describe "C98923 - Verify that 'puppet certregen --help' prints help text" do
      # NOTE: `--help` only works on puppet version 4+
      if version_is_less( '3.9.9', on(default, puppet('--version')).stdout)
        describe command("puppet certregen --help") do
          its(:stdout) { should match( /.*USAGE: puppet certregen <action>.*/ ) }
          its(:stdout) { should match( /.*See 'puppet man certregen' or 'man puppet-certregen' for full help.*/ ) }
        end
      end
    end
    describe "C99812 - Verify that 'puppet help certregen' prints help text" do
        describe command("puppet help certregen") do
          its(:stdout) { should match( /.*USAGE: puppet certregen <action>.*/ ) }
          its(:stdout) { should match( /.*See 'puppet man certregen' or 'man puppet-certregen' for full help.*/ ) }
        end
    end
    describe "C99813 - Verify that 'puppet help certregen healthcheck' prints help text for healthcheck subcommand" do
        describe command("puppet help certregen healthcheck") do
          its(:stdout) { should match( /.*USAGE: puppet certregen healthcheck .*/ ) }
          its(:stdout) { should match( /.*See 'puppet man certregen' or 'man puppet-certregen' for full help.*/ ) }
        end
    end
    describe "C99814 - Verify that 'puppet help certregen ca' prints help text for ca subcommand" do
        describe command("puppet help certregen ca") do
          its(:stdout) { should match( /.*USAGE: puppet certregen ca .*/ ) }
          its(:stdout) { should match( /.*See 'puppet man certregen' or 'man puppet-certregen' for full help.*/ ) }
        end
    end
  end
end
