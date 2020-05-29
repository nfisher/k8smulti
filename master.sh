#!/bin/bash -eu

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp /etc/kubernetes/admin.conf /vagrant/config
chown -R vagrant:vagrant /home/vagrant/.kube

# install calico as k8s network
source /vagrant/networking/calico.sh

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

kubectl apply -f - <<EOF
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

echo "Grafana admin password:"
kubectl get secret --namespace loki-grafana loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo