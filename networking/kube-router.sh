# install kube-router as k8s network
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
kubectl -n kube-system delete ds kube-proxy
ctr image pull k8s.gcr.io/kube-proxy-amd64:v1.15.1
ctr run --privileged --mount type=bind,src=/lib/modules,dst=/lib/modules,options=rbind:ro --net-host k8s.gcr.io/kube-proxy-amd64:v1.15.1 kube-proxy kube-proxy --cleanup || echo "Done cleanup"
ctr c rm kube-proxy

# ctr run --privileged --mount type=bind,src=/lib/modules,dst=/lib/modules --net-host k8s.gcr.io/kube-proxy-amd64:v1.15.1 kube-proxy --cleanup || echo "Done cleanup"
# ctr run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.15.1 kube-proxy --cleanup || echo "Done cleanup"