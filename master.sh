#!/bin/bash -eu

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp /etc/kubernetes/admin.conf /vagrant/config
chown -R vagrant:vagrant /home/vagrant/.kube

# install calico as k8s network
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# install kube-router as k8s network
#kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
#kubectl -n kube-system delete ds kube-proxy
#docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.15.1 kube-proxy --cleanup || echo "Done cleanup"

# install helm things
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 755 get_helm.sh
./get_helm.sh

# add helm repos
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add loki https://grafana.github.io/loki/charts
helm repo update

# install some useful tools
helm install --namespace kube-system metrics-server stable/metrics-server --values=/vagrant/metrics-server-values.yaml
kubectl create namespace nginx-ingress
helm install --namespace nginx-ingress nginx-ingress stable/nginx-ingress --set rbac.create=true --set controller.hostNetwork=true
kubectl create namespace loki-grafana
helm install --namespace loki-grafana loki loki/loki-stack --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false

cat > /tmp/grafana-ingress.yml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: grafana
  namespace: loki-grafana
spec:
  rules:
    - host: grafana.k8smulti.local
      http:
        paths:
          - backend:
              serviceName: loki-grafana
              servicePort: 80
            path: /
EOF
kubectl apply -f /tmp/grafana-ingress.yml

echo "Grafana admin password:"
kubectl get secret --namespace loki-grafana loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo