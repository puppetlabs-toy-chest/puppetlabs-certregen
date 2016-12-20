Facter.add(:has_puppet) do
  setcode do
    begin
      require 'puppet'
      true
    rescue LoadError
      false
    end
  end
end
