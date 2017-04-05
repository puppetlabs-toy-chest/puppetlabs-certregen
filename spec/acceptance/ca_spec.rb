require 'spec_helper_acceptance'

describe "puppet certregen ca" do
  if hosts_with_role(hosts, 'master').length>0 then
    context 'regen ca on master' do

      context 'C99811 - without --ca_serial' do
        it 'should provide ca serial id via stderr' do
          on(master, puppet("certregen ca"), :acceptable_exit_codes => 1) do |result|
            expect(result.stderr).to match(/rerun this command with --ca_serial ([0-9a-fA-F]+)/)
          end
        end
      end

      context "C99815 - 'puppet certregen ca --ca_serial'" do
        before(:all) do
          serial = get_ca_serial_id_on(master)
          today = get_time_on(master)
          @future = today + 5*YEAR
          @regen_result = on(master, "puppet certregen ca --ca_serial #{serial}")
        end
        it 'should output the updated CA expiration date' do
          expect(@regen_result.stdout).to match( /CA expiration is now #{@future.utc.strftime('%Y-%m-%d')}/ )
        end
        it 'should update CA cert enddate' do
          enddate = get_ca_enddate_time_on(master)
          expect(enddate - @future).to be < 10.0
        end
      end

      context 'C99816 - invalid ca_serial id' do
        it 'should yield an error' do
          on(master, puppet("certregen ca --ca_serial FD"), :acceptable_exit_codes => 1) do |result|
            expect(result.stderr).to match(/The serial number of the current CA certificate .* does not match the serial number given on the command line \(FD\)/)
            expect(result.stderr).to match(/rerun this command with --ca_serial ([0-9a-fA-F]+)/)
          end
        end
      end

      context "C99817 - 'puppet certregen ca --ca_serial --ca_ttl 1d'" do
        before(:all) do
          today = get_time_on(master)
          @tomorrow = today + 1*DAY

          serial = get_ca_serial_id_on(master)
          @regen_result = on(master, "puppet certregen ca --ca_serial #{serial} --ca_ttl 1d")
        end

        it 'should output the updated CA expiration date' do
          expect(@regen_result.stdout).to match( /CA expiration is now #{@tomorrow.utc.strftime('%Y-%m-%d')}/ )
        end
        it 'should update CA cert enddate' do
          enddate = get_ca_enddate_time_on(master)
          expect(enddate - @tomorrow).to be < 10.0
        end
      end

    end
  end
end
