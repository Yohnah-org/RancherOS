# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'ipaddr'

## Hacking this until we get a real plugin

# Borrowing from http://stackoverflow.com/questions/1825928/netmask-to-cidr-in-ruby
IPAddr.class_eval do
  def to_cidr
    self.to_i.to_s(2).count("1")
  end
end

module VagrantPlugins
    module GuestLinux
        class Plugin < Vagrant.plugin("2")
            guest_capability("linux", "configure_networks") do
                Cap::ConfigureNetworks
            end
        end

        module Cap
            class ConfigureNetworks

                def self.configure_networks(machine, networks)
                    machine.communicate.tap do |comm|
                        interfaces = []
                        comm.sudo("ip link show|grep eth[1-9]|awk -e '{print $2}'|sed -e 's/:$//'") do |_, result|
                            interfaces = result.split("\n")
                        end

                        networks.each do |network|
                            dhcp = "true"
                            iface = interfaces[network[:interface].to_i - 1]

                            if network[:type] == :static
                                cidr = IPAddr.new(network[:netmask]).to_cidr
                                comm.sudo("rancherctl config set network.interfaces.#{iface}.address #{network[:ip]}/#{cidr}")
                                comm.sudo("rancherctl config set network.interfaces.#{iface}.match #{iface}")

                                dhcp = "false"
                            end
                            comm.sudo("rancherctl config set network.interfaces.#{iface}.dhcp #{dhcp}")
                        end

                        comm.sudo("system-docker restart network")
                    end
                end
            end
        end
    end
end


class VagrantPlugins::ProviderVirtualBox::Action::Network
  def dhcp_server_matches_config?(dhcp_server, config)
    true
  end
end


$msg = <<MSG
Welcome to RancherOS Linux box for Vagrant by Yohnah
=================================================

Further information, see: https://github.com/Yohnah/RancherOS

Reload your terminal to refresh the environment variables

MSG

Vagrant.configure(2) do |config|
  config.vm.post_up_message = $msg
  config.ssh.shell = '/bin/bash'
  config.ssh.username = 'rancher'
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.guest = :linux

  config.vm.provider "virtualbox" do |vb, override|
    vb.check_guest_additions = false
    vb.functional_vboxsf     = false
    vb.memory = 2048
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--uart1", "off"]
    vb.customize ['modifyvm', :id, '--vrde', 'off']
  end

end
