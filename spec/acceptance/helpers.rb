require 'openssl'

# Time constants in seconds
HOUR =  60 * 60
DAY  =  24 * HOUR
YEAR = 365 * DAY

# Retrieve CA Certificate from the given host
#
# @param  [Host]           host   single Beaker::Host
#
# @return [OpenSSL::X509::Certificate]  Certificate object
def get_ca_cert_on(host)
  if host[:roles].include? 'master' then
    dir = on(host, puppet('config', 'print', 'cadir')).stdout.chomp
    ca_path = "#{dir}/ca_crt.pem"
  else
    dir = on(host, puppet('config', 'print', 'certdir')).stdout.chomp
    ca_path = "#{dir}/ca.pem"
  end
  on(host, "cat #{ca_path}") do |result|
    cert = OpenSSL::X509::Certificate.new(result.stdout)
    return cert
  end
end

# Execute `date` command on host with optional arguments
# and get back a Ruby Time object
#
# @param [Host]            host   single Beaker::Host to run the command on
# @param [Array<String>]   args   Array of arguments to be appended to the
#                                 `date` command
# @return [Time]    Ruby Time object
def get_time_on(host, args = [])
  arg_string = args.join(' ')
  date = on(host, "date #{arg_string}").stdout.chomp
  return Time.parse(date)
end

# Retrieve the CA enddate on a given host as a Ruby time object
#
# @param [Host]            host   single Beaker::Host to get CA enddate from
#
# @return [Time]    Ruby Time object, or nil if error
def get_ca_enddate_time_on(host)
  cert = get_ca_cert_on(host)
  return cert.not_after if cert
  return nil
end

# Retrieve the current ca_serial value for `puppet certgen ca` on a given host
#
# @param [Host]            host   single Beaker::Host to get ca_serial from
#
# @return [String]    ca_serial in hexadecimal, or nil if error
def get_ca_serial_id_on(host)
  cert = get_ca_cert_on(host)
  return cert.serial.to_s(16) if cert
  return nil
end

# Patch puppet to get around the date check validation.
#
# This method is used to patch puppet in order to prevent it from failing to
# create a CA if the system clock is turned back in time by years. The same
# method is used to reverse the patch with the `reverse` parameter.
#
# @param [Host]            host     single Beaker::Host to run the command on
# @param [String]          reverse  causes the patch to be reversed
def patch_puppet_date_check_on(host, reverse=nil)
  reverse = '--reverse' if reverse
  apply_manifest_on(host, 'package { "patch": ensure => present}')
  interface_documentation_file = "/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/interface/documentation.rb"
  patch =<<EOF
305c305
<           raise ArgumentError, "copyright with a year \#{fault} is very strange; did you accidentally add or subtract two years?"
---
>           #raise ArgumentError, "copyright with a year \#{fault} is very strange; did you accidentally add or subtract two years?"
EOF
  patch_file        = host.tmpfile('iface_doc_patch')
  create_remote_file(host, patch_file, patch)
  on(host, "patch #{reverse} #{interface_documentation_file} < #{patch_file}", :acceptable_exit_codes => [0,1])
end
