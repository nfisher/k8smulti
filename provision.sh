#!/bin/bash -eux

KUBE_VERSION="1.14.7"; export KUBE_VERSION
K8S_RPM="${KUBE_VERSION}-0"; export K8S_RPM
DOCKER_VERSION="18.09.9-3.el7"; export DOCKER_VERSION
PATH=$PATH:/usr/local/bin; export PATH

# k8s repo setup
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y epel-release

# disable swap
swapoff -a
grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# install OS packages
yum install -y --disableexcludes=kubernetes \
  yum-utils device-mapper-persistent-data lvm2 \
  ipvsadm net-tools htop \
  kernel-devel kernel-headers kernel \
  gcc make \
  docker-ce-${DOCKER_VERSION} \
  kubelet-${K8S_RPM} kubeadm-${K8S_RPM} kubectl-${K8S_RPM}


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
  ]
}
EOF

# networking config
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sysctl --system
modprobe ip_vs

# disable firewall
systemctl disable --now firewalld

# enable docker
systemctl enable --now docker

# enable the kubelet
systemctl enable --now kubelet

if [ "master" = `hostname -s` ]; then
  kubeadm init \
    --kubernetes-version=v${KUBE_VERSION} \
    --token=abcdef.0123456789abcdef \
    --apiserver-advertise-address=192.168.253.100 \
    --pod-network-cidr=10.244.0.0/16
fi

# install helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

# Prepare Install of VirtualBox Guest Additions
mount -r /dev/cdrom /media
/media/VBoxLinuxAdditions.run --noexec

