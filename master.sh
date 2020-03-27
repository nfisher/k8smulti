#!/bin/bash -eu

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# flannel network
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# calico network
#kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml

# kube-router network
# apt-get install -y ipvsadm
#kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
#kubectl -n kube-system delete ds kube-proxy
# clean up existing ipvs and ip-tables rules
#docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.10.2 kube-proxy --cleanup

