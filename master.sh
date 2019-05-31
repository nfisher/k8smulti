#!/bin/bash -eu

KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG
PATH=$PATH:/usr/local/bin; export PATH

kubeadm init --apiserver-advertise-address=192.168.253.100 --kubernetes-version=v1.14.2 --token=abcdef.0123456789abcdef --pod-network-cidr=10.244.0.0/16

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# kuberouter install
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
kubectl -n kube-system delete ds kube-proxy
docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.10.2 kube-proxy --cleanup

# helm install
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
/usr/local/bin/helm init --service-account tiller
/usr/local/bin/helm repo update
