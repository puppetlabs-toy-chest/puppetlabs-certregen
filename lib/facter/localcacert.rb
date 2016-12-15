Facter.add(:localcacert) do
  confine :has_puppet => true
  setcode { Puppet[:localcacert] }
end
