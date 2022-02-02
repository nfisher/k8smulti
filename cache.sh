#!/bin/bash -eu

source /vagrant/versions.rc

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-cacher-ng
echo 'PassThroughPattern: ^(.*):443$' >> /etc/apt-cacher-ng/acng.conf
service apt-cacher-ng restart

echo 'Acquire::http { Proxy "http://192.168.56.99:3142"; };' > /etc/apt/apt.conf.d/02proxy

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
dpkg --remove docker docker-engine docker.io containerd runc

curl -q -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu/ $(lsb_release -cs) stable"

apt-get update
apt-get install -y \
  docker-ce=${DOCKER_VERSION} \
  kubeadm=${KUBE_PKG_VERSION}

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "registry-mirrors": ["http://192.168.56.99:5000"],
  "insecure-registries" : ["192.168.56.99:5000","192.168.56.99:5001"]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
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

docker run -d -p 5001:5000 --restart=always --name local-registry registry:2.7
docker run -d -p 5000:5000 --restart=always -v /etc/docker/registry.yml:/etc/docker/registry/config.yml --name cache-registry registry:2.7

kubeadm config images pull --kubernetes-version=v${KUBE_VERSION}
for IMG in $(kubeadm config images list --kubernetes-version=v${KUBE_VERSION} 2> /dev/null | cut -c 12-);
do
  docker tag k8s.gcr.io/$IMG 192.168.56.99:5001/$IMG
  docker push 192.168.56.99:5001/$IMG
done
