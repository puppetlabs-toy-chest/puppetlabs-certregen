require 'securerandom'
require 'shellwords'
require 'chloride'

require 'puppet'
require 'puppet/util/execution'

module PuppetX
  module Certregen
    module CA
      module_function

      # Abstract API changes for CA cert signing
      #
      # @param ca [Puppet::SSL::CertificateAuthority]
      # @param hostname [String]
      # @param options [Hash<Symbol, Object>]
      def sign(ca, hostname, options)
        if Puppet::PUPPETVERSION >= "4.6.0"
          ca.sign(hostname, options)
        else
          ca.sign(hostname, options[:allow_dns_alt_names], options[:self_signing_csr])
        end
      end

      def setup
        Puppet::SSL::Host.ca_location = :only
        Puppet.settings.preferred_run_mode = "master"

        raise "Not a CA" unless Puppet::SSL::CertificateAuthority.ca?
        unless ca = Puppet::SSL::CertificateAuthority.instance
          raise "Unable to fetch the CA"
        end
        ca
      end

      def backup
        cacert_backup_path = File.join(Puppet[:cadir], "ca_crt.#{Time.now.to_i}.pem")
        Puppet.notice("Backing up current CA certificate to #{cacert_backup_path}")
        FileUtils.cp(Puppet[:cacert], cacert_backup_path)
      end

      def regenerate(ca, cert = Puppet::SSL::Certificate.indirection.find("ca"))
        subject_cn = cert.content.subject.to_a[0][1]

        request = Puppet::SSL::CertificateRequest.new(subject_cn)
        request.generate(ca.host.key)

        PuppetX::Certregen::CA.sign(ca, Puppet::SSL::CA_NAME,
                                    {allow_dns_alt_names: false, self_signing_csr: request})
      end

      # Copy the current CA certificate to the given host.
      #
      # @note Only Linux systems are supported and requires that the localcacert setting on the
      #   given host is the default path.
      #
      # @param [String] hostname The host to copy the CA cert to
      # @param [Hash] config the Chloride host config
      # @return [void]
      def distribute_cacert(hostname, config)
        host = Chloride::Host.new(hostname, config)
        host.ssh_connect

        Puppet.debug("SSH status for #{hostname}: #{host.ssh_status}")

        log_events = lambda do |event|
          event.data[:messages].each do |data|
            Puppet.info "[#{data.severity}:#{data.hostname}]: #{data.message.inspect}"
          end
        end

        src = Puppet[:cacert]
        tmp = "cacert.pem.tmp.#{SecureRandom.uuid}"
        dst ='/etc/puppetlabs/puppet/ssl/certs/ca.pem' # @todo: query node for localcacert

        copy_action = Chloride::Action::FileCopy.new(to_host: host, from: src, to: tmp)
        copy_action.go(&log_events)
        if copy_action.success?
          Puppet.info "Copied #{src} to #{hostname}:#{tmp}"
        else
          raise "Failed to copy #{src} to #{hostname}:#{tmp}: #{copy_action.status}"
        end

        move_action = Chloride::Action::Execute.new(host: host, cmd: "cp #{tmp} #{dst}", sudo: true)

        move_action.go(&log_events)

        if move_action.success?
          Puppet.info "Updated #{hostname}:#{dst} to new CA certificate"
        else
          raise "Failed to copy #{tmp} to #{hostname}:#{dst}"
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
    end
  end
end
