#!/bin/bash -eux

KUBELET_IP=$1; export KUBELET_IP

source /vagrant/versions.rc
source /vagrant/common.sh

PATH=$PATH:/usr/local/bin; export PATH

env_noninteractive

add_apt_proxy

setup_docker_repo
setup_kube_repo

disable_swap

install_kube_and_containerd

run_containerd_with_cache_registry_config

setup_kubelet_networking

run_kubelet_with_ip

if [ "master" = `hostname -s` ]; then
  run_kube_controlplane
else
  run_kube_cluster_join
fi
