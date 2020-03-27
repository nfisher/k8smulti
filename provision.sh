#!/bin/bash -eux

KUBE_VERSION="1.17.4"; export KUBE_VERSION
KUBE_PKG_VERSION="${KUBE_VERSION}-00"; export KUBE_PKG_VERSION
DOCKER_VERSION="5:19.03.8~3-0~debian-$(lsb_release -cs)"; export DOCKER_VERSION
PATH=$PATH:/usr/local/bin; export PATH
DEBIAN_FRONTEND=noninteractive; export DEBIAN_FRONTEND

echo 'Acquire::http { Proxy "http://192.168.253.99:3142"; };' > /etc/apt/apt.conf.d/02proxy

# kernel setup
apt-get update
dpkg --remove docker docker-engine docker.io containerd runc
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# k8s repo setup
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update

# disable swap
swapoff -a
grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab

# install OS packages
apt-get install -y \
  lvm2 net-tools htop \
  containerd.io=1.2.10-3 \
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

# enable the kubelet
systemctl enable --now kubelet

if [ "master" = `hostname -s` ]; then
  kubeadm init \
    --kubernetes-version=v${KUBE_VERSION} \
    --token=abcdef.0123456789abcdef \
    --apiserver-advertise-address=192.168.253.100 \
    --pod-network-cidr=10.217.0.0/16
    #--skip-phases=addon/kube-proxy
fi

# install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
