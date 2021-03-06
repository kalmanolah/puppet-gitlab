require 'spec_helper'

# Gitlab
describe 'gitlab' do
  let(:facts) {{
    :osfamily       => 'Debian',
    :fqdn           => 'gitlab.fooboozoo.fr',
    :processorcount => '2',
    :sshrsakey      => 'AAAAB3NzaC1yc2EAAAA'
  }}

  ## Parameter set
  # a non-default common parameter set
  let :params_set do
    {
      :git_user    => 'gitlab',
      :git_home    => '/srv/gitlab',
      :git_comment => 'Labfooboozoo',
      :git_email   => 'gitlab@fooboozoo.fr',
      :git_proxy   => 'http://proxy.fooboozoo.fr:3128'
    }
  end

  ## Gitlab::setup
  describe 'gitlab::setup' do

    ### User, gitconfig, home and satellites
    describe 'user, home, gitconfig and GitLab satellites' do
      context 'with default params' do
        it { should contain_user('git').with(
          :ensure   => 'present',
          :shell    => '/bin/bash',
          :password => '*',
          :home     => '/home/git',
          :comment  => 'GitLab',
          :system   => true
        )}
        it { should contain_file('/home/git/.gitconfig').with_content(/^\s*name = "GitLab"$/)}
        it { should contain_file('/home/git/.gitconfig').with_content(/^\s*email = git@someserver.net$/)}
        it { should_not contain_file('/srv/gitlab/.gitconfig').with_content(/^\s*proxy$/)}
        it { should contain_file('/home/git').with(:ensure => 'directory', :mode => '0755')}
        it { should contain_file('/home/git/gitlab-satellites').with(:ensure => 'directory', :mode => '0750')}
      end
      context 'with specifics params' do
        let(:params) { params_set }
        it { should contain_user(params_set[:git_user]).with(
          :ensure   => 'present',
          :shell    => '/bin/bash',
          :password => '*',
          :home     => params_set[:git_home],
          :comment  => params_set[:git_comment],
          :system   => true
        )}
        it { should contain_file('/srv/gitlab/.gitconfig').with_content(/^\s*name = "GitLab"$/)}
        it { should contain_file('/srv/gitlab/.gitconfig').with_content(/^\s*email = #{params_set[:git_email]}$/)}
        it { should contain_file('/srv/gitlab/.gitconfig').with_content(/^\s*proxy = #{params_set[:git_proxy]}$/)}
        it { should contain_file('/srv/gitlab').with(:ensure => 'directory',:mode => '0755')}
        it { should contain_file('/srv/gitlab/gitlab-satellites').with(:ensure => 'directory',:mode => '0750')}
      end
    end

    ### Sshkey
    describe  'sshkey (hostfile)' do
      it { should contain_sshkey('localhost').with(
        :ensure       => 'present',
        :host_aliases => 'gitlab.fooboozoo.fr',
        :key          => 'AAAAB3NzaC1yc2EAAAA',
        :type         => 'ssh-rsa'
      )}
    end

    ### Packages setup
    #= Packages helper
    p = {
      'Debian' => {
        'db_packages' => {
          'mysql' => ['libmysql++-dev','libmysqlclient-dev'],
          'pgsql' => ['libpq-dev', 'postgresql-client']
        },
        'system_packages' => ['libicu-dev', 'python2.7','python-docutils',
                              'libxml2-dev','libxslt1-dev','python-dev'],
      },
      'RedHat' => {
        'db_packages' => {
          'mysql' => ['mysql-devel'],
          'pgsql' => ['postgresql-devel']
        },
        'system_packages' => ['libicu-devel','perl-Time-HiRes','libxml2-devel',
                              'libxslt-devel','python-devel','libcurl-devel',
                              'readline-devel','openssl-devel','zlib-devel',
                              'libyaml-devel','patch','gcc-c++'],
      }
    }

    #### Db and devel packages
    describe 'packages' do
      #= On each distro
      ['Debian','RedHat'].each do |distro|
        #= With each dbtype
        ['mysql','pgsql'].each do |dbtype|
          context "for #{dbtype} devel on #{distro}" do
            let(:facts) {{ :osfamily => distro, :processorcount => '2' }}
            let(:params) {{ :gitlab_dbtype => dbtype }}
            p[distro]['db_packages'][dbtype].each do |pkg|
              it { should contain_package(pkg) }
            end
          end
        end
        context "for devel dependencies on #{distro}" do
          let(:facts) {{ :osfamily => distro, :processorcount => '2' }}
          p[distro]['system_packages'].each do |pkg|
            it { should contain_package(pkg) }
          end

          it { should contain_class('git') }
          it { should contain_package('git') }
        end
      end
      #### Gems (all dist.)
      describe 'commons gems' do
        it { should contain_package('bundler').with(
          :ensure   => 'installed',
          :provider => 'gem'
        )}
        it { should contain_package('charlock_holmes').with(
          :ensure   => '0.6.9.4',
          :provider => 'gem'
        )}
      end
      #### Commons packages (all dist.)
      describe 'commons packages' do
        ['postfix','curl'].each do |pkg|
          it { should contain_package(pkg) }
        end
      end
    end # packages
  end # gitlab::setup
end # gitlab
