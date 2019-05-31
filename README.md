# k8smulti

Provides a multinode cluster on your local machine.

Provides:

  - 1 x master (2vcpu & 2GB ram)
  - 2 x nodes (2vcpu & 4GB ram)
  - kube-router - service proxy, firewall, and pod networking.
  - k8s v1.14.2.
  - helm 2.x.
  - api - 192.168.253.100:6443.
  - kube config - ~vagrant/.kube/config

## References

- [kube-router](https://github.com/cloudnativelabs/kube-router/blob/master/docs/index.md) - network overlay.
- [pod-toolbox](https://github.com/cloudnativelabs/kube-router/blob/master/docs/pod-toolbox.md#pod-toolbox) - useful for understanding network behaviour.
