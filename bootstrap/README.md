# Bootstrap

Bootstrap a bare Talos cluster to a fully Flux-managed Kubernetes environment.

## Prerequisites

- [talosctl](https://www.talos.dev/latest/introduction/getting-started/#talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [just](https://github.com/casey/just)
- [helmfile](https://github.com/helmfile/helmfile)
- [yq](https://github.com/mikefarah/yq)

`talosctl` must be configured with the cluster endpoint and node IPs (see [talos/README.md](../talos/README.md)).

The `age.agekey` file must be present at the repository root for SOPS decryption.

## Usage

Run the full bootstrap pipeline:

```sh
just bootstrap
```

This executes the following stages in order:

1. **check** — verifies all required binaries are installed
2. **talos** — applies machine config to nodes (skips already-configured nodes)
2. **kube** — bootstraps the Kubernetes control plane
3. **kubeconfig** — fetches kubeconfig via talosctl
4. **wait** — waits for all nodes to reach Ready
5. **namespaces** — creates namespaces from `kubernetes/apps/` directory structure
6. **resources** — creates the `sops-age` secret in `flux-system`
7. **crds** — applies CRDs for grafana-operator and envoy-gateway
8. **apps** — deploys cilium, flux-operator, and flux-instance via helmfile

Once flux-instance is running, Flux takes over and reconciles all remaining apps from Git.

List available stages:

```sh
just --list bootstrap
```

Run an individual stage:

```sh
just bootstrap <stage>
```
