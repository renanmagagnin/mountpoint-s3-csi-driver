# Uninstall CSI Driver
```
helm uninstall aws-mountpoint-s3-csi-driver --namespace kube-system --ignore-not-found --wait --cascade foreground
```

# Install CSI Driver from source with Mountpoint from source
```
deploy-local-changes-improved.sh --with-mountpoint-from-source
install-csi-driver-helm-chart.sh
```

# Execute and monitor the reproduction 
Execute:
```
bash mountpoint-s3-csi-driver/examples/kubernetes/eviction_test/reproduce-issue-575.sh
```

Monitor for 3-5 minutes:
```
for i in $(seq 1 12); do
  echo "=== $(date +%H:%M:%S) ==="
  kubectl get pods -n mp-eviction-test --no-headers 2>&1
  kubectl get pods -n mount-s3 --no-headers 2>&1
  echo ""
  sleep 30
done
```

```
k describe po <MP-POD> -n mount-s3
```

# Cleanup the reproduction 
```
bash mountpoint-s3-csi-driver/examples/kubernetes/eviction_test/cleanup.sh
```

# Unninstallation
`helm uninstall aws-mountpoint-s3-csi-driver --namespace kube-system --ignore-not-found --wait --cascade foreground`

# Installation 
```
helm upgrade --install aws-mountpoint-s3-csi-driver \
    --namespace kube-system \
    --devel \
    --version 2.4.1 \
    aws-mountpoint-s3-csi-driver/aws-mountpoint-s3-csi-driver
```