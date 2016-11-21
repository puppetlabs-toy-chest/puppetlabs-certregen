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


gem 'puppet', *location_for(ENV['PUPPET_VERSION'] || 'file://../../puppet')
gem 'chloride', "~> 0.2.2"

group :test do
  gem "rspec", "~> 3.5"
  gem "rspec-puppet", "~> 2.5"
  gem 'puppetlabs_spec_helper'
end

group :acceptance do
  gem 'beaker', '< 3.0'
  gem 'beaker-rspec'
  gem 'beaker-hostgenerator'
end

group :development do
  gem 'pry'
  gem 'pry-doc'
  if RUBY_VERSION[0..2] == '1.9'
    gem 'pry-debugger'
  elsif RUBY_VERSION[0] == '2'
    gem 'pry-byebug'
  end
end
