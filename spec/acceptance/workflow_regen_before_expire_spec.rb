require 'spec_helper_acceptance'

# https://forge.puppet.com/puppetlabs/certregen#refresh-a-ca-thats-expiring-soon
describe "C99818 - workflow - regen CA before it expires" do
  if hosts_with_role(hosts, 'master').length>0 then
    # This workflow only works with a master to manage the CA
    context 'setting CA to expire soon' do
      before(:all) do
        serial = get_ca_serial_id_on(master)

        # patch puppet to defeat copywrite date check when generating historical CA
        patch_puppet_date_check_on(master)

        # determine current time on master
        @today = get_time_on(master)

        # set back the clock in order to create a CA that will be approaching its EOL
        past = @today - (5*YEAR - 20*DAY)
        on(master, "date #{past.strftime('%m%d%H%M%Y')}")
        # create old CA
        on(master, puppet(" certregen ca --ca_serial #{serial}"))
        # update to current time
        on(master, "date #{@today.strftime('%m%d%H%M%Y')}")
      end

      it 'should have current date' do
        today = get_time_on(master)
        expect(today.utc.strftime('%Y-%m-%d')).to eq @today.utc.strftime('%Y-%m-%d')
      end

      it 'should warn about pending expiration' do
        enddate = get_ca_enddate_time_on(master)
        on(master, puppet("certregen healthcheck")) do |result|
          expect(result.stdout).to match(/Status:\s+expiring/)
          expect(result.stdout).to match(/Expiration date:\s+#{enddate.utc.strftime('%Y-%m-%d')}/)
        end
      end

      context 'restoring previously patched puppet' do
        before(:all) do
          # revert patch to defeat copywrite date check
          patch_puppet_date_check_on(master, 'reverse')
        end

        context 'regenerating CA prior to expiration' do
          before(:all) do
            serial = get_ca_serial_id_on(master)
            on(master, puppet("certregen ca --ca_serial #{serial}"))
          end
          # validate time stamp
          it 'should update CA cert enddate' do
            enddate = get_ca_enddate_time_on(master)
            future = get_time_on(master, ['-d', "'5 years'"])
            expect(future - enddate).to be <= (48*HOUR)
          end

          context 'distribute new ca to linux hosts that have been classified with `certregen::client`' do
            before(:all) do
              create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/ca.pp', 'include certregen::client')
              on(master, 'chmod 755 /etc/puppetlabs/code/environments/production/manifests/ca.pp')
              on(master, puppet('agent -t'), :acceptable_exit_codes => [0,2])
            end
            it 'should update CA cert on all linux agents' do
              master_enddate = get_ca_enddate_time_on(master)
              agents.each do |agent|
                on(agent, puppet('agent -t'), :acceptable_exit_codes => [0,2])
                enddate = get_ca_enddate_time_on(agent)
                expect(enddate).to eq master_enddate
              end
            end
          end

        end
      end
    end
  end
end
