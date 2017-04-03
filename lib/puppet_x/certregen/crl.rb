require 'fileutils'
require 'openssl'

module PuppetX
  module Certregen
    # @api private
    # @see {Puppet::SSL::CertificateRevocationList}
    module CRL
      module_function

      FIVE_YEARS = 5 * 365*24*60*60

      def refresh(ca)
        crl = ca.crl
        crl_content = crl.content
        update_to_next_crl_number(crl_content)
        update_valid_time_range_to_start_at(crl_content, Time.now)
        sign_with(crl_content, ca.host.key.content)
        Puppet::SSL::CertificateRevocationList.indirection.save(crl)
        FileUtils.cp(Puppet[:cacrl], Puppet[:hostcrl])
        Puppet::SSL::CertificateRevocationList.indirection.find("ca")
      end

      # @api private
      def update_valid_time_range_to_start_at(crl_content, time)
        # The CRL is not valid if the time of checking == the time of last_update.
        # So to have it valid right now we need to say that it was updated one second ago.
        crl_content.last_update = time - 1
        crl_content.next_update = time + FIVE_YEARS
      end

      # @api private
      def update_to_next_crl_number(crl_content)
        crl_content.extensions = with_next_crl_number_from(crl_content, crl_content.extensions)
      end

      # @api private
      def with_next_crl_number_from(crl_content, existing_extensions)
        existing_crl_num = existing_extensions.find { |e| e.oid == 'crlNumber' }
        new_crl_num = existing_crl_num ? existing_crl_num.value.to_i + 1 : 0
        extensions_without_crl_num = existing_extensions.reject { |e| e.oid == 'crlNumber' }
        extensions_without_crl_num + [crl_number_of(new_crl_num)]
      end

      # @api private
      def crl_number_of(number)
        OpenSSL::X509::Extension.new('crlNumber', OpenSSL::ASN1::Integer(number))
      end

      # @api private
      def sign_with(crl_content, cakey)
        crl_content.sign(cakey, OpenSSL::Digest::SHA1.new)
      end
    end
  end
end
