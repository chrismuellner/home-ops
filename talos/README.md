# Talos

Set up a single-node talos cluster to work with cilium:

1. Configure endpoint
```
export ENDPOINT=https://<ip>:6443
```
2. Get `talos-secret.yaml` secret
3. Run command
```
talosctl gen config k8s $ENDPOINT \
    --with-secrets talos-secrets.yaml \
    --config-patch-control-plane @patches/controlplane.yaml \
    --output-types controlplane,talosconfig \
    --with-examples=false
```
4. Update `talosconfig` with endpoint (simplifies `talosctl` usage)
```
contexts
    k8s:
        endpoints:
        - $ENDPOINT
        nodes:
        - $ENDPOINT
```