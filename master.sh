#!/bin/bash -eu

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

helm repo add cilium https://helm.cilium.io/
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

helm install cilium cilium/cilium --version 1.7.1 \
    --namespace kube-system \
    --set global.kubeProxyReplacement=probe \
    --set global.k8sServiceHost=192.168.253.100 \
    --set global.k8sServicePort=6443

kubectl create namespace nginx-ingress
helm install nginx-ingress --namespace nginx-ingress stable/nginx-ingress --set rbac.create=true --set controller.hostNetwork=true
