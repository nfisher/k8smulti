#!/bin/bash -eux

KUBELET_IP=$1; export KUBELET_IP

source /vagrant/versions.rc

PATH=$PATH:/usr/local/bin; export PATH
DEBIAN_FRONTEND=noninteractive; export DEBIAN_FRONTEND

echo 'Acquire::http { Proxy "http://192.168.253.99:3142"; };' > /etc/apt/apt.conf.d/02proxy


dpkg --remove docker docker-engine docker.io containerd runc

# k8s repo setup
curl -q -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
curl -q -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# disable swap
swapoff -a
grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab

# install OS packages
apt-get update -qq
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common \
  lvm2 net-tools htop \
  containerd.io=${CONTAINERD_VERSION} \
  docker-ce=${DOCKER_VERSION} docker-ce-cli=${DOCKER_VERSION} \
  kubelet=${KUBE_PKG_VERSION} kubeadm=${KUBE_PKG_VERSION} kubectl=${KUBE_PKG_VERSION}

# Docker daemon config
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "registry-mirrors": ["http://192.168.253.99:5000"],
  "insecure-registries" : ["192.168.253.99:5000","192.168.253.99:5001"]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker

# networking config
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sysctl --system
modprobe ip_vs

# enable docker
systemctl enable --now docker

echo "KUBELET_EXTRA_ARGS=--node-ip=${KUBELET_IP}" > /etc/default/kubelet

# enable the kubelet
systemctl enable --now kubelet
systemctl daemon-reload
systemctl restart kubelet.service

if [ "master" = `hostname -s` ]; then
  cp /vagrant/cluster.yaml .
  echo "kubernetesVersion: v${KUBE_VERSION}" >> cluster.yaml
  kubeadm init --config=cluster.yaml
    #--pod-network-cidr=10.217.0.0/16
else
  kubeadm join \
    192.168.253.100:6443 \
    --token abcdef.0123456789abcdef \
    --discovery-token-unsafe-skip-ca-verification
fi
