#!/bin/bash -eu

source /vagrant/versions.rc
source /vagrant/common.sh

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y apt-cacher-ng
echo 'PassThroughPattern: ^(.*):443$' >> /etc/apt-cacher-ng/acng.conf
service apt-cacher-ng restart

echo 'Acquire::http { Proxy "http://192.168.56.99:3142"; };' > /etc/apt/apt.conf.d/02proxy

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

setup_docker_repo

setup_kube_repo

apt-get update

install_kube_and_docker

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/' /etc/containerd/config.toml
sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/' /etc/containerd/config.toml

cat > /etc/docker/daemon.json.old <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "registry-mirrors": ["http://192.168.56.99:5000"],
  "insecure-registries" : ["192.168.56.99:5000","192.168.56.99:5001"]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
systemctl restart containerd
systemctl restart docker

cat > /etc/docker/registry.yml <<EOF
version: 0.1
log:
  level: debug
  fields:
    service: registry
    environment: development
  hooks:
    - type: mail
      disabled: true
      levels:
        - panic
      options:
        smtp:
          addr: mail.example.com:25
          username: mailuser
          password: password
          insecure: true
        from: sender@example.com
        to:
          - errors@example.com
storage:
    delete:
      enabled: true
    cache:
        blobdescriptor: redis
    filesystem:
        rootdirectory: /var/lib/registry
    maintenance:
        uploadpurging:
            enabled: false
http:
    addr: :5000
    debug:
        addr: :5001
        prometheus:
            enabled: true
            path: /metrics
    headers:
        X-Content-Type-Options: [nosniff]
redis:
  addr: localhost:6379
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s
  dialtimeout: 10ms
  readtimeout: 10ms
  writetimeout: 10ms
notifications:
    events:
        includereferences: true
    endpoints:
        - name: local-5003
          url: http://localhost:5003/callback
          headers:
             Authorization: [Bearer <an example token>]
          timeout: 1s
          threshold: 10
          backoff: 1s
          disabled: true
        - name: local-8083
          url: http://localhost:8083/callback
          timeout: 1s
          threshold: 10
          backoff: 1s
          disabled: true 
proxy:
  remoteurl: https://registry-1.docker.io
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

docker run -d -p 5001:5000 --restart=always --name local-registry registry:2
docker run -d -p 5000:5000 --restart=always -v /etc/docker/registry.yml:/etc/docker/registry/config.yml --name cache-registry registry:2

kubeadm config images pull --kubernetes-version=v${KUBE_VERSION} --cri-socket=/run/containerd/containerd.sock
echo "Done Pull"

curl -LO https://github.com/containerd/nerdctl/releases/download/v1.3.1/nerdctl-1.3.1-linux-amd64.tar.gz
tar xzf nerdctl-1.3.1-linux-amd64.tar.gz

for IMG in $(kubeadm config images list --kubernetes-version=v${KUBE_VERSION} 2> /dev/null | cut -f2-3 -d'/');
do
  ./nerdctl tag --namespace k8s.io registry.k8s.io/$IMG 192.168.56.99:5001/$IMG
  ./nerdctl push --namespace k8s.io --insecure-registry 192.168.56.99:5001/$IMG
  # lazy fix for coredns having a subdir
  ./nerdctl tag --namespace k8s.io registry.k8s.io/$IMG 192.168.56.99:5001/coredns/$IMG
  ./nerdctl push --namespace k8s.io --insecure-registry 192.168.56.99:5001/coredns/$IMG
done
