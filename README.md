# k8smulti

Provides a multinode cluster on your local machine.

## Provides

  - 1 x master (2vcpu & 2GB ram)
  - 2 x nodes (2vcpu & 4GB ram)
  - kube-router - service proxy, firewall, and pod networking.
  - k8s v1.14.2.
  - helm 2.x.
  - API - 192.168.253.100:6443.
  - kube config - ~vagrant/.kube/config

## Required Software

  - [Vagrant](https://www.vagrantup.com)
  - [VirtualBox](https://www.virtualbox.org)

## Getting Started

 1. Install the required software.
 2. Run `vagrant up master` to provision the master node.
 3. Run `vagrant ssh master` and check the master is ready with `kubectl get nodes -o wide`.
 4. Run `vagrant up` to provision the nodes.
 5. Run `vagrant ssh master`, check the nodes are ready with `kubectl get nodes -o wide`.
 6. To browse grafana add `192.168.253.101 grafana.k8smulti.local` to `/etc/hosts`.

**Note**: Kubernetes config is available in `/home/vagrant/.kube/config` on the master.

## Networking Overview

### Calico - CIDR Ranges

| Name           | Network          |
| -------------- | ---------------- |
| Host           | 192.168.253.0/24 |
| Pods (default) | 10.217.0.0/16    |
| Pods (pool1)   | 10.218.1.0/24    |
| Pods (pool2)   | 10.218.2.0/24    |

## References

- [kube-router](https://github.com/cloudnativelabs/kube-router/blob/master/docs/index.md) - network overlay.
- [pod-toolbox](https://github.com/cloudnativelabs/kube-router/blob/master/docs/pod-toolbox.md#pod-toolbox) - useful for understanding network behaviour.
