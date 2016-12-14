Facter.add(:hostcrl) do
  confine do
    begin
      require 'puppet'
      true
    rescue LoadError
      false
    end
  end

  setcode { Puppet[:hostcrl] }
end
