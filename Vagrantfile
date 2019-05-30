# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "centos/7"
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--audio", "none"]
  end

  config.vm.provision "shell", path: "provision.sh"

  config.vm.define "master" do |node|
    node.vm.network "private_network", ip: "192.168.253.100"
    node.vm.hostname = "master"
    node.vm.provision "shell", inline: <<-EOT
    kubeadm init --apiserver-advertise-address=192.168.253.100 --kubernetes-version=v1.14.2 --token=abcdef.0123456789abcdef --pod-network-cidr=10.244.0.0/16
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system delete ds kube-proxy
    docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.10.2 kube-proxy --cleanup
    EOT
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
    end
  end

  config.vm.define "node01" do |node|
    node.vm.network "private_network", ip: "192.168.253.101"
    node.vm.hostname = "node01"
    node.vm.provision "shell", inline: <<-EOT
    kubeadm join 192.168.253.100:6443 --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification
    EOT
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "node02" do |node|
    node.vm.network "private_network", ip: "192.168.253.102"
    node.vm.hostname = "node02"
    node.vm.provision "shell", inline: <<-EOT
    kubeadm join 192.168.253.100:6443 --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification
    EOT
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

end
