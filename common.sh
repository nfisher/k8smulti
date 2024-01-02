# Try to keep the functions in alphabetical order.

add_apt_proxy() {
    echo 'Acquire::http { Proxy "http://192.168.56.99:3142"; };' > /etc/apt/apt.conf.d/02proxy
}

apt_update() {
    apt-get update
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

setup_docker_repo() {
    dpkg --remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
   tee /etc/apt/sources.list.d/docker.list > /dev/null
}

setup_kube_repo() {
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
}
