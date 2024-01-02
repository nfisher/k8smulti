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

install_kube_and_docker() {
    apt-get install -y \
        docker-ce=${DOCKER_VERSION} \
        kubeadm=${KUBE_PKG_VERSION}
}

disable_swap() {
   swapoff -a
    grep -v swap /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab 
}