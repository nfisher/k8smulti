# Try to keep the functions in alphabetical order.

add_apt_proxy() {
    echo 'Acquire::http { Proxy "http://192.168.56.99:3142"; };' > /etc/apt/apt.conf.d/02proxy
}

apt_update() {
    apt-get update
}

cache_kube_images() {
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
}

disable_swap() {
    swapoff -a
    grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab
}

env_noninteractive() {
    DEBIAN_FRONTEND=noninteractive; export DEBIAN_FRONTEND
}

install_ca_certs() {
    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
}

install_apt_cache() {
    apt_update
    apt-get install -y apt-cacher-ng
    echo 'PassThroughPattern: ^(.*):443$' >> /etc/apt-cacher-ng/acng.conf
    service apt-cacher-ng restart
}

install_kube_and_docker() {
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common \
        lvm2 net-tools htop \
        docker-ce=${DOCKER_VERSION} \
        kubeadm=${KUBE_PKG_VERSION}
}

install_kube_and_containerd() {
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common \
        lvm2 net-tools htop \
        containerd.io=${CONTAINERD_VERSION} \
        kubelet=${KUBE_PKG_VERSION} kubeadm=${KUBE_PKG_VERSION} kubectl=${KUBE_PKG_VERSION}
}

run_docker_proxy() {
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
    docker run -d -p 5000:5000 --restart=always -v /etc/docker/registry.yml:/etc/docker/registry/config.yml --name cache-registry registry:2
}

run_docker_registry() {
    docker run -d -p 5001:5000 --restart=always --name local-registry registry:2
}

run_containerd_with_default_config() {
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/' /etc/containerd/config.toml
    sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/' /etc/containerd/config.toml

    systemctl daemon-reload
    systemctl restart containerd
}

run_containerd_with_cache_registry_config() {
    mkdir -p /etc/containerd

    cat <<EOF > /etc/containerd/config.toml
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"
plugin_dir = ""
disabled_plugins = []
required_plugins = []
oom_score = 0

[grpc]
  address = "/var/run/containerd/containerd.sock"
  tcp_address = ""
  tcp_tls_cert = ""
  tcp_tls_key = ""
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[ttrpc]
  address = ""
  uid = 0
  gid = 0

[debug]
  address = ""
  uid = 0
  gid = 0
  level = ""

[metrics]
  address = ""
  grpc_histogram = false

[cgroup]
  path = ""

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"

[plugins]
  [plugins."io.containerd.gc.v1.scheduler"]
    pause_threshold = 0.02
    deletion_threshold = 0
    mutation_threshold = 100
    schedule_delay = "0s"
    startup_delay = "100ms"
  [plugins."io.containerd.grpc.v1.cri"]
    disable_tcp_service = true
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    stream_idle_timeout = "4h0m0s"
    enable_selinux = false
    selinux_category_range = 1024
    sandbox_image = "k8s.gcr.io/pause:3.2"
    stats_collect_period = 10
    systemd_cgroup = false
    enable_tls_streaming = false
    max_container_log_line_size = 16384
    disable_cgroup = false
    disable_apparmor = false
    restrict_oom_score_adj = false
    max_concurrent_downloads = 3
    disable_proc_mount = false
    unset_seccomp_profile = ""
    tolerate_missing_hugetlb_controller = true
    disable_hugetlb_controller = true
    ignore_image_defined_volumes = false
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      no_pivot = false
      disable_snapshot_annotations = true
      discard_unpacked_layers = false
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        runtime_type = ""
        runtime_engine = ""
        runtime_root = ""
        privileged_without_host_devices = false
        base_runtime_spec = ""
      [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
        runtime_type = ""
        runtime_engine = ""
        runtime_root = ""
        privileged_without_host_devices = false
        base_runtime_spec = ""
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          runtime_engine = ""
          runtime_root = ""
          privileged_without_host_devices = false
          base_runtime_spec = ""
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["http://192.168.56.99:5000"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."192.168.56.99:5001"]
          endpoint = ["http://192.168.56.99:5001"]
    [plugins."io.containerd.grpc.v1.cri".image_decryption]
      key_model = ""
    [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
      tls_cert_file = ""
      tls_key_file = ""
  [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"
  [plugins."io.containerd.internal.v1.restart"]
    interval = "10s"
  [plugins."io.containerd.metadata.v1.bolt"]
    content_sharing_policy = "shared"
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
  [plugins."io.containerd.runtime.v1.linux"]
    shim = "containerd-shim"
    runtime = "runc"
    runtime_root = ""
    no_shim = false
    shim_debug = false
  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]
  [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    root_path = ""
    pool_name = ""
    base_image_size = ""
    async_remove = false
EOF

    systemctl daemon-reload
    systemctl restart containerd
}

run_kubelet_with_ip() {
    echo "KUBELET_EXTRA_ARGS=--node-ip=${KUBELET_IP}" > /etc/default/kubelet

    # enable the kubelet
    systemctl enable --now kubelet
    systemctl daemon-reload
    systemctl restart kubelet.service
}

run_kube_controlplane() {
    YAML=cluster-24.yaml
    cp /vagrant/${YAML} .
    echo "kubernetesVersion: v${KUBE_VERSION}" >> ${YAML}
    kubeadm init --config=${YAML}
}

run_kube_cluster_join() {
    kubeadm join \
    192.168.56.100:6443 \
    --token abcdef.0123456789abcdef \
    --discovery-token-unsafe-skip-ca-verification
}

setup_docker_repo() {
    dpkg --remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
   tee /etc/apt/sources.list.d/docker.list > /dev/null
}

setup_kubelet_networking() {
    modprobe br_netfilter ip_vs

# networking config
    cat <<EOF >  /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.lxc*.rp_filter        = 0
EOF
    sysctl --system
}

setup_kube_repo() {
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
}
