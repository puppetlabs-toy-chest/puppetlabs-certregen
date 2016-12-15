Facter.add(:hostcrl) do
  confine :has_puppet => true
  setcode { Puppet[:hostcrl] }
end
