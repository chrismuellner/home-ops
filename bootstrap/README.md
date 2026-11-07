# Bootstrap

Bootstrap a bare Talos cluster to a fully Flux-managed Kubernetes environment.

## Prerequisites

- [mise](https://mise.jdx.dev/) — run `mise install` at the repository root to install the
  pinned tools from `mise.toml` (talosctl, kubectl, just, helmfile, helm, yq, ...)

`talosctl` must be configured with the cluster endpoint and node IPs (see [talos/README.md](../talos/README.md)).

The `age.agekey` file must be present at the repository root for SOPS decryption.

## Usage

Run the full bootstrap pipeline:

```sh
just bootstrap
```

This executes the following stages in order:

1. **check** — installs the tools pinned in `mise.toml` via `mise install`
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
