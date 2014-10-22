VAGRANTFILE_API_VERSION = "2"

path = "#{File.dirname(__FILE__)}"

require 'yaml'
require path + '/scripts/homestead.rb'

config_file = (File.file?(path + '/Homestead.yaml')) ? '/Homestead.yaml' : '/Homestead.default.yaml'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  Homestead.configure(config, YAML::load(File.read(path + config_file)))
end
