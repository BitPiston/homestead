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
      config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil
    end

    # install crontabs
    Homestead.install_cron_tabs(config, settings)

    # Install All The Configured Nginx Sites
    settings["sites"].each do |site|
      config.vm.provision "shell" do |s|
          if (site.has_key?("hhvm") && site["hhvm"])
            s.inline = "bash /vagrant/scripts/serve-hhvm.sh $1 $2"
            s.args = [site["map"], site["to"]]
          else
            s.inline = "bash /vagrant/scripts/serve.sh $1 $2"
            s.args = [site["map"], site["to"]]
          end
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
    # Configure All Of The Server Environment Variables
    if settings.has_key?("variables")
      settings["variables"].each do |var|
        config.vm.provision "shell" do |s|
            s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php5/fpm/php-fpm.conf && service php5-fpm restart"
            s.args = [var["key"], var["value"]]
        end
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

  def Homestead.install_cron_tabs(config, settings)
    # empty /home/vagrant/.crontabs file
    config.vm.provision "shell" do |s|
      s.inline = "cat /dev/null > /home/vagrant/.crontabs"
    end

    # fill /home/vagrant/.crontabs file with crontab rows
    settings["crontabs"].each do |crontab|
      config.vm.provision "shell" do |s|
        s.inline = "echo #{Homestead.crontab_value_of(crontab["minute"])} #{Homestead.crontab_value_of(crontab["hour"])} #{Homestead.crontab_value_of(crontab["monthday"])} #{Homestead.crontab_value_of(crontab["month"])} #{Homestead.crontab_value_of(crontab["weekday"])} #{crontab["command"] } >> /home/vagrant/.crontabs"
      end
    end

    # install all crontabs from /home/vagrant/.crontabs file for 'root'
    config.vm.provision "shell" do |s|
      s.inline = "crontab -u root /home/vagrant/.crontabs"
    end
  end

  def Homestead.crontab_value_of(input)
    input != nil && input != '*' ? input : "\\*"
  end
end
