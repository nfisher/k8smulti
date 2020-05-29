export DATASTORE_TYPE=kubernetes
export KUBECONFIG=/etc/kubernetes/admin.conf

curl -q -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.14.1/calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin/calicoctl
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

cat > /tmp/pools.yaml <<EOT
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool01
spec:
  cidr: 10.218.1.0/24
  vxlanMode: Always
  natOutgoing: true
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool02
spec:
  cidr: 10.218.2.0/24
  vxlanMode: Always
  natOutgoing: true
EOT

/usr/local/bin/calicoctl apply -f /tmp/pools.yaml

cat > /tmp/namespaces.yaml <<EOT
---
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    cni.projectcalico.org/ipv4pools: "[\"pool01\"]"
  name: nspool01
---
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    cni.projectcalico.org/ipv4pools: "[\"pool02\"]"
  name: nspool02
EOT
kubectl apply -f /tmp/namespaces.yaml