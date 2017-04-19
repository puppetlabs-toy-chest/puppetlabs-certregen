require 'puppet_x/certregen/util'

module PuppetX
  module Certregen
    module Certificate
      module_function

      # @param cert [Puppet::SSL::Certificate]
      # @return [Hash<Symbol, String>]
      def expiry(cert)
        if cert.content.not_after < Time.now
          status = :expired
        elsif expiring?(cert)
          status = :expiring
        else
          status = :ok
        end

        data = {
          :status => status,
          :expiration_date => cert.content.not_after
        }

        if status != :expired
          data[:expires_in] = PuppetX::Certregen::Util.duration(cert.content.not_after - Time.now)
        end

        data
      end

      # Is this certificate expiring or expired?
      #
      # @param cert [Puppet::SSL::Certificate]
      # @param percent [Integer]
      def expiring?(cert, percent = 10)
        remaining = cert.content.not_after - Time.now
        lifetime = cert.content.not_after - (cert.content.not_before + 86400)
        remaining / lifetime < (percent / 100.0)
      end
    end
  end
end
