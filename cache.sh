#!/bin/bash -eu

source /vagrant/versions.rc
source /vagrant/common.sh

env_noninteractive

install_apt_cache

add_apt_proxy

setup_docker_repo
setup_kube_repo

install_kube_and_docker

run_containerd_with_default_config

run_docker_registry
run_docker_proxy

cache_kube_images
