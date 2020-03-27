# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/stretch64"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
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
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "256"
    end

    node.vm.network "forwarded_port", guest: 5000, host: 5000
    node.vm.network "private_network", ip: "192.168.253.99"
    node.vm.hostname = "cache"

    node.vm.provision "shell", path: "cache.sh"
  end


  #
  # master configuration
  #
  config.vm.define "master" do |node|
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1536"
    end

    node.vm.network "private_network", ip: "192.168.253.100"
    node.vm.hostname = "master"

    node.vm.provision "shell", path: "provision.sh"
    node.vm.provision "shell", inline: <<-EOT
      echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.253.100' > /etc/default/kubelet
      systemctl daemon-reload
      systemctl restart kubelet.service
    EOT
    node.vm.provision "shell", path: "master.sh"
  end


  #
  # node01 configuration
  #
  config.vm.define "node01" do |node|
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end

    node.vm.network "private_network", ip: "192.168.253.101"
    node.vm.hostname = "node01"

    node.vm.provision "shell", path: "provision.sh"
    node.vm.provision "shell", inline: <<-EOT
      echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.253.101' > /etc/default/kubelet
      systemctl daemon-reload
      systemctl restart kubelet.service
      kubeadm join 192.168.253.100:6443 --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification
    EOT
  end


  #
  # node02 configuration
  #
  config.vm.define "node02" do |node|
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end

    node.vm.network "private_network", ip: "192.168.253.102"
    node.vm.hostname = "node02"

    node.vm.provision "shell", path: "provision.sh"
    node.vm.provision "shell", inline: <<-EOT
      echo 'KUBELET_EXTRA_ARGS=--node-ip=192.168.253.102' > /etc/default/kubelet
      systemctl daemon-reload
      systemctl restart kubelet.service
      kubeadm join 192.168.253.100:6443 --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification
    EOT
  end

end
