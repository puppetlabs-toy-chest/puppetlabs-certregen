require 'puppet_x/certregen/util'

module PuppetX
  module Certregen
    module Certificate
      module_function

      # @param cert [Puppet::SSL::Certificate]
      # @return [Array<Array<String, String>>]
      def expiry(cert)
        if cert.content.not_after < Time.now
          status = :expired
        elsif expiring?(cert)
          status = :expiring
        else
          status = :ok
        end

        data = [['Status', status], ['Expiration date', cert.content.not_after]]

        if status != :expired
          data << ['Expires in', PuppetX::Certregen::Util.duration(cert.content.not_after - Time.now)]
        end

        data
      end

      # Is this certificate expiring or expired?
      #
      # @param cert [Puppet::SSL::Certificate]
      # @param percent [Integer]
      def expiring?(cert, percent = 10)
        remaining = cert.content.not_after - Time.now
        lifetime = cert.content.not_after - cert.content.not_before
        remaining / lifetime < (percent / 100.0)
      end
    end
  end
end
