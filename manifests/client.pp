# Distribute the current Puppet CA certificate to client systems.
#
# To ensure the portability of this code and minimize dependencies, this class uses the `file`
# function to distribute the CA certificate instead of having end nodes directly fetch the
# certificate themselves. This means that Puppet installations using a master of master/CA server
# and compile nodes will need to run Puppet on the compile masters before the CA cert can be
# distributed to the agents.
class certregen::client(
  $manage_crl = true
) {
  file { $localcacert:
    ensure  => present,
    content => file($settings::cacert, $settings::localcacert, "/dev/null"),
    mode    => '0644',
  }

  $crl_managed_by_pe = ($pe_build and versioncmp($pe_build, '3.7.0') >= 0) and is_classified_with('puppet_enterprise::profile::master')
  $needs_crl = $manage_crl and !defined(File[$::hostcrl]) and !$crl_managed_by_pe

  if $needs_crl {
    file { $hostcrl:
      ensure  => present,
      content => file($settings::cacrl, $settings::hostcrl, "/dev/null"),
      mode    => '0644',
    }
  }
}
