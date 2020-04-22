# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
    vb.customize ["modifyvm", :id, "--largepages", "on"]
    vb.customize ["modifyvm", :id, "--vtxvpid", "on"]
    vb.customize ["modifyvm", :id, "--vtxux", "on"]
  end

  #
  # cache configuration
  #
  config.vm.define "cache" do |node|
    resources(node, 1, 512)

    node.vm.network "private_network", ip: "192.168.253.99"
    node.vm.hostname = "cache"
    node.vm.provision "shell", path: "cache.sh"
  end


  #
  # master configuration
  #
  config.vm.define "master" do |node|
    resources(node, 2, 2048)

    node.vm.network "private_network", ip: "192.168.253.100"
    node.vm.hostname = "master"

    node.vm.provision :shell, inline: "sed 's/127\\.0\\.1\\.1.*master.*/192\\.168\\.253\\.100 master/' -i /etc/hosts"
    node.vm.provision "shell", path: "provision.sh", args: ["192.168.253.100"]
    node.vm.provision "shell", path: "master.sh"
  end


  #
  # node01 configuration
  #
  config.vm.define "node01" do |node|
    resources(node, 2, 4096)

    node.vm.network "private_network", ip: "192.168.253.101"
    node.vm.hostname = "node01"

    node.vm.provision :shell, inline: "sed 's/127\\.0\\.1\\.1.*node01.*/192\\.168\\.253\\.101 node01/' -i /etc/hosts"
    node.vm.provision "shell", path: "provision.sh", args: ["192.168.253.101"]
  end


  #
  # node02 configuration
  #
  config.vm.define "node02" do |node|
    resources(node, 2, 4096)

    node.vm.network "private_network", ip: "192.168.253.102"
    node.vm.hostname = "node02"

    node.vm.provision :shell, inline: "sed 's/127\\.0\\.1\\.1.*node02.*/192\\.168\\.253\\.102 node02/' -i /etc/hosts"
    node.vm.provision "shell", path: "provision.sh", args: ["192.168.253.102"]
  end

end

def resources(node, cpu, memory)
    node.vm.provider "virtualbox" do |vb|
      vb.cpus = cpu.to_i
      vb.memory = memory.to_s
    end

    node.vm.provider "vmware_desktop" do |v|
      v.vmx["numvcpus"] = cpu.to_s
      v.vmx["memsize"] = memory.to_s
    end
end