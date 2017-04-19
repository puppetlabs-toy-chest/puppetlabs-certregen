require 'spec_helper_acceptance'
require 'yaml'
require 'json'

describe "puppet certregen healthcheck" do
  if hosts_with_role(hosts, 'master').length>0 then

    context 'C99803 - cert with more than 10 percent of life' do
      before(:all) do
        serial = get_ca_serial_id_on(master)
        on(master, "puppet certregen ca --ca_serial #{serial}")
      end
      it 'should not produce a health warning' do
        on(master, "puppet certregen healthcheck") do |result|
          expect(result.stderr).to be_empty
          expect(result.stdout).to match(/No certificates are approaching expiration/)
        end
      end
    end

    context 'C99804 - cert with less than 10 percent of life' do
      before(:all) do
        serial = get_ca_serial_id_on(master)
        # patch puppet to defeat copywrite date check when generating historical CA
        patch_puppet_date_check_on(master)
        @today = get_time_on(master)
        # set back the clock in order to create a CA that will be approaching its EOL
        past = @today - (5*YEAR - 20*DAY)
        on(master, "date #{past.strftime('%m%d%H%M%Y')}")
        # create old CA
        on(master, "puppet certregen ca --ca_serial #{serial}")
        # update to current time
        on(master, "date #{@today.strftime('%m%d%H%M%Y')}")
        # revert patch to defeat copywrite date check
        patch_puppet_date_check_on(master, 'reverse')
      end

      it 'system should have current date' do
        today = get_time_on(master)
        expect(today.utc.strftime('%Y-%m-%d')).to eq @today.utc.strftime('%Y-%m-%d')
      end

      it 'should warn about pending expiration' do
        enddate = get_ca_enddate_time_on(master)
        on(master, "puppet certregen healthcheck") do |result|
          expect(result.stdout).to match(/Status:\s+expiring/)
          expect(result.stdout).to match(/Expiration date:\s+#{enddate.utc.strftime('%Y-%m-%d')}/)
        end
      end

    end

    context 'C99805 - expired cert' do
      before(:all) do
        serial = get_ca_serial_id_on(master)
        on(master, "puppet certregen ca --ca_serial #{serial} --ca_ttl 1s")
        sleep 2
      end
      it 'should produce a health warning' do
        on(master, "puppet certregen healthcheck") do |result|
          expect(result.stdout.gsub("\n", " ")).to match(/ca.*Status: expired/)
        end
      end
    end

    context '--all flag' do

      context 'C99806 --all' do
        before(:all) do
          on(master, puppet("cert list --all")) do |result|
            @certs = result.stdout.scan(/\) ([A-F0-9:]+) /)
          end
          @result = on(master, "puppet certregen healthcheck --all")
        end
        it 'should contain expiration data for ca cert' do
          expect(@result.stdout).to match(/"ca".*\n\s*Status:\s*[Ee]xpir/)
        end
        it 'should contain expiration data for all node certs' do
          @certs.each do |cert|
            expect(@result.stdout).to include cert[0]
          end
        end
      end

      context '--render-as flag' do

        context 'C99808 - --render-as yaml' do
          before(:all) do
            on(master, puppet("cert list --all")) do |result|
              @certs = result.stdout.scan(/\) ([A-F0-9:]+) /)
            end
            @result = on(master, "puppet certregen healthcheck --all --render-as yaml")
            @yaml = YAML.load(@result.stdout)
          end
          it 'should return valid yaml' do
            expect(YAML.parse(@result.stdout)).to be_instance_of(Psych::Nodes::Document)
          end
          it 'should contain expiration data for ca cert' do
            ca = @yaml.find { |record| record[:name] == 'ca' }
            expect(ca).not_to be nil
            expect(ca[:expiry][:status]).to eq(:expired)
          end
          it 'should contain expiration data for all node certs' do
            @certs.each do |cert|
              expect(@yaml.find { |record| record[:digest] =~ /#{cert[0]}/ }).not_to be nil
            end
          end
        end

        context 'C99809 - --render-as json prints valid json containing expiration data' do
          before(:all) do
            on(master, puppet("cert list --all")) do |result|
              @certs = result.stdout.scan(/\) ([A-F0-9:]+) /)
            end
            @json = JSON.parse(on(master, "puppet certregen healthcheck --all --render-as json").stdout)
          end
          it 'should return valid json' do
            expect(@json).not_to be nil
          end
          it 'should contain expiration data for ca cert' do
            ca = @json.find { |record| record['name'] == 'ca' }
            expect(ca).not_to be nil
          end
          it 'should contain expiration data for all node certs' do
            @certs.each do |cert|
              expect(@json.find { |record| record['digest'] =~ /#{cert[0]}/ }).not_to be nil
            end
          end
        end

      end
    end

  end
end
