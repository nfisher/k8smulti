#!/bin/bash -eux

PATH=$PATH:/usr/local/bin; export PATH
KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG

# copy kube config into vagrant users home
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp /etc/kubernetes/admin.conf /vagrant/config
chown -R vagrant:vagrant /home/vagrant/.kube

kubectl apply -f /vagrant/psp.yaml


# install helm things
curl -q -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 755 get_helm.sh
./get_helm.sh

# install CNI network
source /vagrant/networking/calico-latest.sh
#source /vagrant/networking/cilium.sh

# add helm repos
helm repo add stable https://charts.helm.sh/stable
helm repo update

# install some useful tools
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

exit 0

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
