require 'spec_helper_acceptance'
require 'json'

# https://forge.puppet.com/puppetlabs/certregen#revive-a-ca-thats-already-expired
describe "C99821 - workflow - regen CA after it expires" do
  if find_install_type == 'pe' then
    # This workflow only works with a master to manage the CA
    # This workflow only works with a puppetdb instance to query hostnames from
    context 'create CA to be expired and update agents' do
      before(:all) do
        ttl = 60
        serial = get_ca_serial_id_on(master)
        on(master, puppet("certregen ca --ca_serial #{serial} --ca_ttl #{ttl}s"))
        start = Time.now
        agents.each do |agent|
          on(agent, puppet('agent -t'), :acceptable_exit_codes => [0,2])
        end
        finish = Time.now
        elapsed_time = (finish - start).to_i
        sleep (ttl - elapsed_time) if elapsed_time < ttl
        sleep 1
      end

      it 'should warn that ca is expired' do
        on(master, puppet("certregen healthcheck")) do |result|
          expect(result.stdout).to match(/Status:\s+expired/)
        end
      end

      context 'regenerate CA' do
        before(:all) do
          serial = get_ca_serial_id_on(master)
          on(master, puppet("certregen ca --ca_serial #{serial}"))
        end

        it 'should update CA cert enddate' do
          enddate = get_ca_enddate_time_on(master)
          future = get_time_on(master, ['-d', "'5 years'"])
          expect(future - enddate).to be <= (48*HOUR)
        end

        context 'automatically distribute new ca to linux hosts' do
          before(:all) do
            # distribute ssh key for root to agents
            on(master, "ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -P ''")
            on(master, "cat $HOME/.ssh/id_rsa.pub") do |result|
              key_array = result.stdout.split(' ')
              fail_test('could not get ssh key from master') unless key_array.size > 1
              @public_key = key_array[1]
            end
            agents.each do |agent|
              unless agent['platform'] =~ /windows/
                args = ['ensure=present',
                        "user='root'",
                        "type='rsa'",
                        "key='#{@public_key}'",
                       ]
                on(agent, puppet_resource('ssh_authorized_key', master.hostname, args))
                on(master, "ssh -o StrictHostKeyChecking=no #{agent.hostname} ls")
              end
            end
            on(master, "/opt/puppetlabs/puppet/bin/gem install chloride")
            result = on(master, puppet("certregen redistribute"))
            @report = JSON.parse(result.stdout)
          end

          after(:all) do
            on(master, "rm -f $HOME/.ssh/id_rsa $HOME/.ssh/id_rsa.pub", :acceptable_exit_codes => [0,1])
            agents.each do |agent|
              on(agent, puppet_resource('ssh_authorized_key', master.hostname, ['ensure=absent', "user='root'"]), :acceptable_exit_codes => [0,1])
            end
          end

          it 'should emit a report in valid json' do
            expect(@report).not_to be nil
          end
          it 'should emit a report with a succeeded key' do
            expect(@report['succeeded']).not_to be nil
          end
          it 'should emit a report with a failed key' do
            expect(@report['failed']).not_to be nil
          end
          it 'should report success on all linux agents' do
            agents.each do |agent|
              if agent['platform'] =~ /debian|ubuntu|cumulus|huaweios|el-|centos|fedora|redhat|oracle|scientific|eos|archlinux|sles/
                expect(@report['succeeded']).to include agent.hostname
              end
            end
          end
          it 'should update CA cert on all linux agents' do
            master_enddate = get_ca_enddate_time_on(master)
            agents.each do |agent|
              if agent['platform'] =~ /debian|ubuntu|cumulus|huaweios|el-|centos|fedora|redhat|oracle|scientific|eos|archlinux|sles/
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
