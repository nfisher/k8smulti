#!/bin/bash -eu

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# flannel CNI network
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# kuberouter install
#kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
#kubectl -n kube-system delete ds kube-proxy
# clean up existing ipvs and ip-tables rules
#docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.10.2 kube-proxy --cleanup

# helm setup
kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --history-max 100 --service-account tiller

# add some useful cluster tools
#helm repo add loki https://grafana.github.io/loki/charts
#helm repo update
#helm upgrade --install loki loki/loki-stack
#helm install stable/grafana -n loki-grafana

#echo "Grafana admin login"
#kubectl get secret loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
