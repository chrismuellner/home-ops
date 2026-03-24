# CLAUDE.md — home-ops

Single-node Talos Linux Kubernetes cluster managed with Flux GitOps.

## Repository Structure

```
home-ops/
├── kubernetes/
│   ├── apps/              # Applications organized by namespace
│   │   ├── cert-manager/
│   │   ├── flux-system/
│   │   ├── home-automation/
│   │   ├── kube-system/
│   │   ├── media/
│   │   ├── network/
│   │   ├── observability/
│   │   ├── selfhosted/
│   │   ├── system/
│   │   └── system-upgrade/
│   ├── components/        # Reusable Kustomize components (e.g. volsync)
│   └── flux/
│       └── cluster/
│           └── ks.yaml    # Root Flux Kustomization — entry point for all apps
├── bootstrap/             # Helmfile bootstrap; only needed when reinstalling the cluster
│   └── helmfile.d/
├── talos/                 # Talos OS machine config and patches
│   ├── controlplane.yaml
│   ├── patches/
│   └── talosconfig
└── .github/
    └── renovate.json5     # Renovate config for automated dependency updates
```

## Kubernetes App Pattern

Every application follows a two-level structure:

```
kubernetes/apps/<namespace>/<appname>/
├── ks.yaml              # Flux Kustomization resource (lives in flux-system namespace)
└── app/
    ├── kustomization.yaml   # Plain Kustomize manifest listing files in app/
    ├── helmrelease.yaml     # Flux HelmRelease referencing the OCIRepository
    ├── ocirepository.yaml   # OCI chart source (oci://ghcr.io/bjw-s-labs/helm/app-template)
    └── <app>-secret.sops.yaml  # SOPS-encrypted secrets (if needed)
```

**Important distinctions:**
- `ks.yaml` is a **Flux** `Kustomization` resource (namespace: `flux-system`) that drives reconciliation
- `app/kustomization.yaml` is a plain **Kustomize** manifest, not a Flux resource — it just lists files

All apps use the [bjw-s/app-template](https://bjw-s-labs.github.io/helm-charts/docs/app-template/) chart via OCIRepository, not HelmRepository. Key value sections: `controllers`, `service`, `persistence`, `route`, `configMaps`. Routes use Envoy Gateway `HTTPRoute` resources pointing to `envoy-internal` in the `network` namespace.

## Flux Patterns

- Source: `GitRepository/home-ops` in `flux-system`
- `kubernetes/flux/cluster/ks.yaml` is the root — it patches all HelmReleases with cluster-wide defaults (CRD handling, remediation, timeouts)
- Use `chartRef` (OCIRepository), not `sourceRef` + `HelmRepository`
- `dependsOn` is common — apps typically depend on `openebs` or other prerequisites
- `postBuild.substitute` provides variable substitution (e.g. `APP`, `VOLSYNC_CAPACITY`)
- Reusable Kustomize components live in `kubernetes/components/` (e.g. volsync backup config)

## Secret Management

- Encrypted with [SOPS](https://getsops.io/) + age; config in `.sops.yaml`
- Encrypted files are named `*.sops.yaml`; encryption covers `data` and `stringData` fields
- `age.agekey` is present locally at the repo root but **not committed** — bootstrap uses it to create the `sops-age` secret in `flux-system`
- Never edit `.sops.yaml` files directly — use `sops <file>` to open, edit, and re-encrypt

## CLI Tools

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes cluster interaction |
| `flux` | Flux CD — check status, reconcile, view logs |
| `talosctl` | Talos OS management (uses `talos/talosconfig`) |
| `just` | Task runner — see `bootstrap/mod.just` and `talos/mod.just` |
| `helmfile` | Bootstrap-only: deploys cilium, flux-operator, flux-instance |
| `sops` | Encrypt/decrypt `*.sops.yaml` secret files |
| `yamlfmt` | YAML formatter (run automatically via lefthook on commit) |

## Common Namespaces

| Namespace | Contents |
|-----------|---------|
| `cert-manager` | cert-manager for TLS certificates |
| `flux-system` | Flux CD controllers, GitRepository, Kustomization resources |
| `home-automation` | Home Assistant, Mosquitto MQTT, Zigbee2MQTT |
| `kube-system` | Cilium CNI, metrics-server |
| `media` | Jellyfin, Immich, *arr stack, qBittorrent, SABnzbd, Seerr |
| `network` | Envoy Gateway, certificates |
| `observability` | Grafana, kube-prometheus-stack |
| `selfhosted` | Paperless-ngx, Tandoor Recipes |
| `system` | OpenEBS, Volsync/Kopia backups, CSI NFS driver, Reloader |
| `system-upgrade` | Talos/Kubernetes upgrade controller (TUPR) |

## Conventions

- **YAML formatting**: All `.yaml` files must pass `yamlfmt` — runs automatically as a pre-commit hook via lefthook. Run `yamlfmt <file>` after edits.
- **Schema comments**: Files include `# yaml-language-server: $schema=...` lines for IDE validation — preserve these when editing.
- **SOPS files**: Never commit plaintext secrets. Files matching `*.sops.yaml` must stay encrypted.
- **Single node**: No node selectors, tolerations, or anti-affinity rules needed.
- **Dependency updates**: Renovate handles image tags, Helm chart versions, and Talos/Kubernetes upgrades via automated PRs.

## Available Skills

- `/k8s-view [namespace] [resource]` — Inspect live cluster state using read-only `kubectl` and `flux` commands. Use this to check HelmRelease/Kustomization health, pod status, and logs.
