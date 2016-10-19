require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.include PuppetlabsSpec::Files
  c.mock_with :rspec
end
