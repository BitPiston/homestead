class Homestead
  def Homestead.configure(config, settings)
    # Configure The Box
    config.vm.box = "ubuntu/trusty64"
    config.vm.hostname = "homestead"

    # Configure A Private Network IP
    config.vm.network :private_network, ip: settings["ip"] ||= "10.0.0.100"

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.name = 'homestead'
      vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
      vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
    end

    # Vagrant Cachier
    if Vagrant.has_plugin?("vagrant-cachier")
      config.cache.scope = :box
      config.cache.enable :apt
      config.cache.enable :bower
      config.cache.enable :composer
      config.cache.enable :npm
      config.cache.enable :generic, { "wget" => { cache_dir: "/var/cache/wget" } }
      config.cache.synced_folder_opts = { type: :nfs, mount_options: ['rw', 'vers=3', 'tcp', 'nolock'] }
    end

    # Run The Base Provisioning Script
    config.vm.provision "shell" do |s|
      s.path = "./scripts/provision.sh"
    end

    # Configure Port Forwarding To The Box
    settings["ports"].each do |port|
      config.vm.network "forwarded_port", guest: port["guest"], host: port["host"] ||= nil
    end

    # Configure The Public Key For SSH Access
    config.vm.provision "shell" do |s|
      s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo $1 | tee -a /home/vagrant/.ssh/authorized_keys"
      s.args = [File.read(File.expand_path(settings["authorize"]))]
    end

    # Copy The SSH Private Keys To The Box
    settings["keys"].each do |key|
      config.vm.provision "shell" do |s|
        s.privileged = false
        s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
        s.args = [File.read(File.expand_path(key)), key.split('/').last]
      end
    end

    # Copy The Bash Aliases
    config.vm.provision "shell" do |s|
      s.inline = "cp /vagrant/aliases /home/vagrant/.bash_aliases"
    end

    # Register All Of The Configured Shared Folders
    settings["folders"].each do |folder|
      if folder.key?("options")
        # Options hash takes precedence
        options = folder["options"]
      else
        # Check for type key for backwards compatibility
        options = Hash.new
        options[:type] = folder.key?("type") ? folder["type"] : nil
      end
      config.vm.synced_folder folder["map"], folder["to"], options
    end

    # Install All The Configured Nginx Sites
    settings["sites"].each do |site|
      config.vm.provision "shell" do |s|
        if (site.has_key?("hhvm") && site["hhvm"])
          s.inline = "bash /vagrant/scripts/serve-hhvm.sh $1 $2"
        else
          s.inline = "bash /vagrant/scripts/serve.sh $1 $2"
        end
        s.args = [site["map"], site["to"]]
      end
    end

    # Updating the hosts file with all the sites that are defined in Homestead.yaml
    if Vagrant.has_plugin?("vagrant-hostsupdater")
        hosts = []
        settings["sites"].each do |site|
          hosts.push(site["map"])
        end
        config.hostsupdater.aliases = hosts
    end

    # Create Databases
    settings["databases"].each do |database|
      config.vm.provision "shell" do |s|
        s.privileged = false
        if (database["type"] == "mysql")
          s.inline = "mysql --user=\"root\" --password=\"secret\" -e \"CREATE DATABASE $1;\" ; true"
        elsif (database["type"] == "postgresql")
          s.inline = "sudo -u postgres /usr/bin/createdb --echo --owner=homestead $1 ; true"
        end
        s.args = [database["name"]]
      end
    end

    # Override php.ini settings
    if settings.has_key?("php_config")
      filename = '/etc/php5/fpm/php.ini'
      settings["php_config"].each do |var|
        key = var.map{ |key, value| key }[0]
        value = var.map{ |key, value| value }[0]
        config.vm.provision "shell" do |s|
          s.inline = "sed -i 's/^\\(#{key}\\).*/\\1 \= #{value}/' #{filename}"
        end
      end
      config.vm.provision "shell" do |s|
        s.inline = "service php5-fpm restart"
      end
    end

    # Configure All Of The Server Environment Variables
    if settings.has_key?("variables")
      settings["variables"].each do |var|
        config.vm.provision "shell" do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php5/fpm/php-fpm.conf"
          s.args = [var["key"], var["value"]]
        end
      end
      config.vm.provision "shell" do |s|
        s.inline = "service php5-fpm restart"
      end
    end

    # Install crontabs
    if settings.has_key?("crontabs")
      # Empty /home/vagrant/.crontabs file
      config.vm.provision "shell" do |s|
        s.inline = "cat /dev/null > /home/vagrant/.crontabs"
      end
      # Fill /home/vagrant/.crontabs file with crontab rows
      settings["crontabs"].each do |crontab|
        crontab.each do |key, val|
          next if key == "command"
          crontab[key] = "\\*" unless val != nil && val != '*'
        end
        config.vm.provision "shell" do |s|
          s.inline = "echo #{crontab["minute"]} #{crontab["hour"]} #{crontab["monthday"]} #{crontab["month"]} #{crontab["weekday"]} #{crontab["command"] } >> /home/vagrant/.crontabs"
        end
      end
      # Install all crontabs from /home/vagrant/.crontabs file for 'root'
      config.vm.provision "shell" do |s|
        s.inline = "crontab -u root /home/vagrant/.crontabs"
      end
    end

  end
end
