# Talos

Set up a single-node talos cluster to work with cilium:

1. Get `talos-secret.yaml` secret
2. Run command
```
just talos genconfig <ip>
```
3. Continue with [Bootstrap](../bootstrap/)