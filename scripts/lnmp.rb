# Main Lnmp Class
class Lnmp
  def self.configure(config, settings)
    # Set The VM Provider
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

    # Configure Local Variable To Access Scripts From Remote Location
    script_dir = File.dirname(__FILE__)

    # Allow SSH Agent Forward from The Box
    config.ssh.forward_agent = true

    # Configure The Box
    config.vm.define settings['name'] ||= 'vagrant-lnmp'
    config.vm.box = settings['box'] ||= 'cluster/lnmp'
    config.vm.hostname = settings['hostname'] ||= 'vagrant-lnmp'

    # Configure A Private Network IP
    if settings['ip'] != 'autonetwork'
      config.vm.network :private_network, ip: settings['ip'] ||= '192.168.10.10'
    else
      config.vm.network :private_network, ip: '0.0.0.0', auto_network: true
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider 'virtualbox' do |vb|
      vb.name = settings['name'] ||= 'vagrant-lnmp'
      vb.customize ['modifyvm', :id, '--memory', settings['memory'] ||= '2048']
      vb.customize ['modifyvm', :id, '--cpus', settings['cpus'] ||= '1']
      vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      vb.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
      vb.customize ['modifyvm', :id, '--ostype', 'Ubuntu_64']
    end

    # Standardize Ports Naming Schema
    if settings.has_key?('ports')
      settings['ports'].each do |port|
        port['guest'] ||= port['to']
        port['host'] ||= port['send']
        port['protocol'] ||= 'tcp'
      end
    else
      settings['ports'] = []
    end

    # Default Port Forwarding
    default_ports = {
      80 => 80,
      443 => 443,
      3306 => 3306,
      6379 => 6379,
    }

    # Use Default Port Forwarding Unless Overridden
    unless settings.has_key?('default_ports') && settings['default_ports'] == false
      default_ports.each do |guest, host|
        unless settings['ports'].any? { |mapping| mapping['guest'] == guest }
          config.vm.network 'forwarded_port', guest: guest, host: host, auto_correct: true
        end
      end
    end

    # Add Custom Ports From Configuration
    if settings.has_key?('ports')
      settings['ports'].each do |port|
        config.vm.network 'forwarded_port', guest: port['guest'], host: port['host'], protocol: port['protocol'], auto_correct: true
      end
    end

    # Register All Of The Configured Shared Folders
    if settings.include? 'folders'
      settings['folders'].each do |folder|
        if File.exist? File.expand_path(folder['map'])
          config.vm.synced_folder folder['map'], folder['to']
        else
          config.vm.provision 'shell', inline: "echo \"Unable to mount one of your folders. Please check your folders in Lnmp.yaml\""
        end
      end
    end

    # Creates folder for opt-in features lockfiles
    config.vm.provision "Mkdir Features", type: "shell", inline: "mkdir -p /home/vagrant/.features"
    config.vm.provision "Chown Features", type: "shell", inline: "chown -Rf vagrant:vagrant /home/vagrant/.features"

    #change software source
    if settings.has_key?('sources')
      config.vm.provision 'shell' do |s|
        s.name = 'Change Software Source'
        s.path = script_dir + '/change-sources.sh'
        s.args = [settings['sources']]
      end
    end

    # Clear any existing nginx sites
    config.vm.provision 'shell' do |s|
      s.path = script_dir + '/clear-nginx.sh'
    end

    # Clear sites and insert markers in /etc/hosts
    config.vm.provision 'shell' do |s|
      s.path = script_dir + '/hosts-reset.sh'
    end

    # Install All The Configured Nginx Sites
    if settings.include? 'sites'
      site_default = false

      settings['sites'].each do |site|
        # Default site configuration, Only allow the first site with default configuration to be valid
        if site_default == false and site['default'] == true
          default = 'true'
          site_default = true
        end

        # Create SSL certificate
        config.vm.provision 'shell' do |s|
          s.name = 'Creating Certificate: ' + site['map']
          s.path = script_dir + '/create-certificate.sh'
          s.args = [site['map']]
        end

        config.vm.provision 'shell' do |s|
          s.name = 'Creating Site: ' + site['map']
          if site.include? 'params'
            params = '('
            site['params'].each do |param|
              params += ' [' + param['key'] + ']=' + param['value']
            end
            params += ' )'
          end
          if site.include? 'headers'
            headers = '('
            site['headers'].each do |header|
              headers += ' [' + header['key'] + ']=' + header['value']
            end
            headers += ' )'
          end
          if site.include? 'rewrites'
            rewrites = '('
            site['rewrites'].each do |rewrite|
              rewrites += ' [' + rewrite['map'] + ']=' + "'" + rewrite['to'] + "'"
            end
            rewrites += ' )'
            # Escape variables for bash
            rewrites.gsub! '$', '\$'
          end

          # Convert the site & any options to an array of arguments passed to the
          # specific site script (defaults to laravel)
          s.path = script_dir + "/nginx.sh"
          s.args = [
              site['map'],                # $1
              site['to'],                 # $2
              site['port'] ||= '80',      # $3
              site['ssl'] ||= '443',      # $4
              params ||= '',              # $5
              headers ||= '',             # $6
              rewrites ||= '',            # $7
              default ||= 'false'         # $8
          ]
        end

        config.vm.provision 'shell' do |s|
          s.path = script_dir + "/hosts-add.sh"
          s.args = ['127.0.0.1', site['map']]
        end
      end
      # Restart Nginx
      config.vm.provision "Restart Nginx", type: "shell", inline: "systemctl restart nginx"
    end

    # Configure All Of The Configured Databases
    if settings.has_key?('databases')
      settings['databases'].each do |db|
        config.vm.provision 'shell' do |s|
          s.name = 'Creating MySQL Database: ' + db
          s.path = script_dir + '/create-mysql.sh'
          s.args = [db]
        end
      end
    end

    if settings.has_key?('backup') && settings['backup'] && (Vagrant::VERSION >= '2.1.0' || Vagrant.has_plugin?('vagrant-triggers'))
      dir_prefix = '/vagrant/.backup'

      # Loop over each DB
      settings['databases'].each do |database|
        # Backup MySQL
        Lnmp.backup_mysql(database, "#{dir_prefix}/mysql_backup", config)
      end
    end
  end

  def self.backup_mysql(database, dir, config)
    now = Time.now.strftime("%Y%m%d%H%M")
    config.trigger.before :destroy do |trigger|
      trigger.warn = "Backing up mysql database #{database}..."
      trigger.run_remote = {inline: "mkdir -p #{dir}/#{now} && mysqldump --routines #{database} > #{dir}/#{now}/#{database}-#{now}.sql"}
    end
  end
end
