require 'spec_helper_acceptance'

describe "C98923 - Verify that 'puppet certregen --help' prints help text" do
  # NOTE: `--help` only works on puppet version 4+
  major = 0
  on(default, puppet('--version')) do |result|
    x,y = result.stdout.split('.')
    major = x.to_i
  end
  if major > 3 then
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
