#!/bin/bash -eu

export DATASTORE_TYPE=kubernetes
export KUBECONFIG=/etc/kubernetes/admin.conf

curl https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml -O
kubectl apply -f calico.yaml

