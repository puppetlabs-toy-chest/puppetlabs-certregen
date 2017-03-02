source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place, fake_version = nil)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end


gem 'puppet', *location_for(ENV['PUPPET_VERSION'] || '~> 4.7')
gem 'chloride', "~> 0.2"

group :test do
  gem "rspec", "~> 3.5"
  gem "rspec-puppet", "~> 2.5"
  gem 'puppetlabs_spec_helper'
end

group :system_tests do
  gem 'beaker', *location_for(ENV['BEAKER_VERSION'] || '>= 3')
  gem 'beaker-pe',                                                               :require => false
  gem 'beaker-rspec', *location_for(ENV['BEAKER_RSPEC_VERSION'])
  gem 'beaker-puppet_install_helper',                                            :require => false
  gem 'beaker-module_install_helper',                                            :require => false
  gem 'master_manipulator',                                                      :require => false
  gem 'beaker-hostgenerator', *location_for(ENV['BEAKER_HOSTGENERATOR_VERSION'])
  gem 'beaker-abs', *location_for(ENV['BEAKER_ABS_VERSION'] || '~> 0.1')
end

group :development do
  gem 'puppet-blacksmith', '>= 3.4.0',      :require => false, :platforms => 'ruby'
  gem 'pry'
  gem 'pry-doc'
  if RUBY_VERSION[0..2] == '1.9'
    gem 'pry-debugger'
  elsif RUBY_VERSION[0] == '2'
    gem 'pry-byebug'
  end
end
