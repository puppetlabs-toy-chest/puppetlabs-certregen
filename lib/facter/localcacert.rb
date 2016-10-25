Facter.add(:localcacert) do
  confine do
    begin
      require 'puppet'
      true
    rescue LoadError
      false
    end
  end

  setcode { Puppet[:localcacert] }
end
