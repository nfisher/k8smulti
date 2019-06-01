#!/bin/bash -eu

KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

kubeadm init \
  --kubernetes-version=v1.14.2 \
  --token=abcdef.0123456789abcdef \
  --apiserver-advertise-address=192.168.253.100 \
  --pod-network-cidr=10.244.0.0/16
  #--service-cidr=192.168.253.0/24 \

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# flannel CNI network
#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# kuberouter install
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
kubectl -n kube-system delete ds kube-proxy
# clean up existing ipvs and ip-tables rules
docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.10.2 kube-proxy --cleanup

# helm install
kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

/usr/local/bin/helm init --history-max 100 --service-account tiller
