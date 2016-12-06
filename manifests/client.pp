# Distribute the current Puppet CA certificate to client systems.
#
# To ensure the portability of this code and minimize dependencies, this class uses the `file`
# function to distribute the CA certificate instead of having end nodes directly fetch the 
# certificate themselves. This means that Puppet installations using a master of master/CA server
# and compile nodes will need to run Puppet on the compile masters before the CA cert can be
# distributed to the agents.
class certregen::client {
  if $settings::ca {
    $cert = file($settings::cacert)
  } else {
    $cert = file($settings::localcacert)
  }

  # TODO: Windows support
  file { $localcacert:
    ensure  => present,
    content => $cert,
    mode    => '0644',
  }
}
