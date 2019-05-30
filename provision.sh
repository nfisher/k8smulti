#!/bin/bash -eux

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

# disable swap
swapoff -a
grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y docker ipvsadm net-tools kubelet kubeadm kubectl --disableexcludes=kubernetes 

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

