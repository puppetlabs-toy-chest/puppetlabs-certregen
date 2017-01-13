require 'securerandom'
require 'shellwords'

require 'puppet'
require 'puppet/util/execution'
require 'puppet/util/package'

require 'puppet/feature/chloride'

module PuppetX
  module Certregen
    module CA
      module_function

      def setup
        Puppet::SSL::Host.ca_location = :only
        Puppet.settings.preferred_run_mode = "master"

        if !Puppet::SSL::CertificateAuthority.ca?
          raise "Unable to set up CA: this node is not a CA server."
        end

        if Puppet::SSL::Certificate.indirection.find('ca').nil?
          raise "Unable to set up CA: the CA certificate is not present."
        end

        Puppet::SSL::CertificateAuthority.instance
      end

      def backup
        cacert_backup_path = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
        Puppet.notice("Backing up current CA certificate to #{cacert_backup_path}")
        FileUtils.cp(Puppet[:cacert], cacert_backup_path)
      end

      # Generate an updated CA certificate with the same subject as the existing CA certificate
      # and synchronize the new CA certificate with the local CA certificate.
      def regenerate(ca, cert = Puppet::SSL::Certificate.indirection.find("ca"))
        Puppet[:ca_name] = cert.content.subject.to_a[0][1]

        request = Puppet::SSL::CertificateRequest.new(Puppet::SSL::Host::CA_NAME)
        request.generate(ca.host.key)
        PuppetX::Certregen::CA.sign(ca, Puppet::SSL::CA_NAME,
                                    {allow_dns_alt_names: false, self_signing_csr: request})
        FileUtils.cp(Puppet[:cacert], Puppet[:localcacert])
      end

      # Copy the current CA certificate and CRL to the given host.
      #
      # @note Only Linux systems are supported and requires that the localcacert/hostcrl setting on the
      #   given host is the default path.
      #
      # @param [String] hostname The host to copy the CA cert to
      # @param [Hash] config the Chloride host config
      # @return [void]
      def distribute(hostname, config)
        host = Chloride::Host.new(hostname, config)
        host.ssh_connect

        Puppet.debug("SSH status for #{hostname}: #{host.ssh_status}")

        log_events = lambda do |event|
          event.data[:messages].each do |data|
            Puppet.info "[#{data.severity}:#{data.hostname}]: #{data.message.inspect}"
          end
        end

        distribute_cacert(host, log_events)
        distribute_crl(host, log_events)
      end

      def distribute_cacert(host, blk)
        src = Puppet[:cacert]
        dst ='/etc/puppetlabs/puppet/ssl/certs/ca.pem' # @todo: query node for localcacert
        distribute_file(host, src, dst, blk)
      end

      def distribute_crl(host, blk)
        src = Puppet[:cacrl]
        dst ='/etc/puppetlabs/puppet/ssl/crl.pem' # @todo: query node for hostcrl
        distribute_file(host, src, dst, blk)
      end

      def distribute_file(host, src, dst, blk)
        tmp = "#{File.basename(src)}.tmp.#{SecureRandom.uuid}"

        copy_action = Chloride::Action::FileCopy.new(to_host: host, from: src, to: tmp)
        copy_action.go(&blk)
        if copy_action.success?
          Puppet.info "Copied #{src} to #{host.hostname}:#{tmp}"
        else
          raise "Failed to copy #{src} to #{host.hostname}:#{tmp}: #{copy_action.status}"
        end

        move_action = Chloride::Action::Execute.new(host: host, cmd: "cp #{tmp} #{dst}", sudo: true)
        move_action.go(&blk)

        if move_action.success?
          Puppet.info "Updated #{host.hostname}:#{dst}"
        else
          raise "Failed to copy #{tmp} to #{host.hostname}:#{dst}"
        end

      end


      # Enumerate Puppet nodes without relying on PuppetDB
      #
      # If the Puppet CA certificate has expired we cannot rely on PuppetDB working
      # or being able to connect to Postgres via the network. In order to access
      # this information while the CA is in a degraded state we perform the query
      # directly via a local psql call.
      def certnames
        psql = '/opt/puppetlabs/server/bin/psql -d pe-puppetdb --pset format=unaligned --pset t=on -c %s'
        query = 'SELECT certname FROM certnames WHERE deactivated IS NULL AND expired IS NULL;'
        cmd = psql % Shellwords.escape(query)
        Puppet::Util::Execution.execute(cmd,
                                        uid: 'pe-postgres',
                                        gid: 'pe-postgres').split("\n")

      end

      # Abstract API changes for CA cert signing
      #
      # @param ca [Puppet::SSL::CertificateAuthority]
      # @param hostname [String]
      # @param options [Hash<Symbol, Object>]
      def sign(ca, hostname, options)
        if Puppet::Util::Package.versioncmp(Puppet::PUPPETVERSION, "4.6.0") != -1
          ca.sign(hostname, options)
        else
          ca.sign(hostname, options[:allow_dns_alt_names], options[:self_signing_csr])
        end
      end
    end
  end
end
