# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

VAGRANTFILE_API_VERSION ||= "2"
confDir = $confDir ||= File.expand_path(File.dirname(__FILE__))

lnmpYamlPath = confDir + "/Lnmp.yaml"

require File.expand_path(File.dirname(__FILE__) + '/scripts/lnmp.rb')

Vagrant.require_version '>= 2.2.4'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    if File.exist? lnmpYamlPath then
        settings = YAML::load(File.read(lnmpYamlPath))
    else
        abort "Lnmp settings file not found in #{confDir}"
    end

    Lnmp.configure(config, settings)
end
