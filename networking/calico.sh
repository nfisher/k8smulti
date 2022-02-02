export DATASTORE_TYPE=kubernetes
export KUBECONFIG=/etc/kubernetes/admin.conf

curl -q -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.14.1/calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin/calicoctl
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# create 2 subnet pools
/usr/local/bin/calicoctl apply -f - <<EOT
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
  vxlanMode: CrossSubnet
  natOutgoing: true
EOT

# create 2 namespaces that use the subnet pools
kubectl apply -f - <<EOT
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

# secure master node
calicoctl apply -f - << EOT
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: ingress-k8s-masters
spec:
  selector: has(node-role.kubernetes.io/master)
  # This rule allows ingress to the Kubernetes API server.
  ingress:
  - action: Allow
    protocol: TCP
    destination:
      ports:
      # kube API server
      - 6443
  # This rule allows all traffic to localhost.
  - action: Allow
    destination:
      nets:
      - 127.0.0.1/32
EOT


# calicoctl apply -f -
cat > /tmp/worker-policy.yaml << EOF
# secure worker nodes
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: ingress-k8s-workers
spec:
  selector: !has(node-role.kubernetes.io/master)
  # Allow all traffic to localhost.
  ingress:
  - action: Allow
    destination:
      nets:
      - 127.0.0.1/32
  # Allow only the masters access to the nodes kubelet API.
  - action: Allow
    protocol: TCP
    source:
      selector: has(node-role.kubernetes.io/master)
    destination:
      ports:
      - 10250
---
# secure host
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: k8s-worker
spec:
  selector: !has(node-role.kubernetes.io/master)
  order: 0
  ingress:
  - action: Allow
    protocol: TCP
    source:
      nets:
      - "192.168.56.0/24"
    destination:
      ports: [22]
  - action: Allow
    protocol: ICMP
  - action: Allow
    protocol: TCP
    destination:
      ports: [10250]
  egress:
  - action: Allow
    protocol: TCP
    destination:
      nets:
      - "192.168.56.100/32"
      ports: [2379]
  - action: Allow
    protocol: UDP
    destination:
      ports: [53, 67]
EOF