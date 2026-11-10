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
│   ├── components/        # Reusable Kustomize components (e.g. kopiur)
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
- `postBuild.substitute` provides variable substitution (e.g. `APP`, `KOPIUR_CAPACITY`, read by the kopiur backup component)
- Reusable Kustomize components live in `kubernetes/components/` (e.g. kopiur backup config)

## DNS

DNS records are managed by two external-dns instances in `kubernetes/apps/network/external-dns/` — do not create route records by hand in Cloudflare or UniFi.

- `external-dns-unifi` (LAN): every hostname on a route attached to `envoy-internal` gets an A record to the gateway's address in UniFi. Also reads `DNSEndpoint` resources for other LAN records.
- `external-dns-cloudflare` (public): every hostname on a route attached to `envoy-external` gets an unproxied CNAME to `external.muellner.dev`, set by the `external-dns.kubernetes.io/target` annotation on the gateway.
- `external.muellner.dev` is the only manual record; the router's DDNS client keeps it on the WAN IP.
- Routes attached to both gateways rely on this split: LAN clients reach `envoy-internal`, public clients `envoy-external`.
- Both instances run with `policy: sync`: removing a hostname from a route deletes its record. Records without an external-dns ownership TXT record are never touched.
- The UniFi instance needs the router API at `https://192.168.10.1` (firewall: DMZ → Gateway, TCP 443).

## Secret Management

- Encrypted with [SOPS](https://getsops.io/) + age; config in `.sops.yaml`
- Encrypted files are named `*.sops.yaml`; encryption covers `data` and `stringData` fields
- `age.agekey` is present locally at the repo root but **not committed** — bootstrap uses it to create the `sops-age` secret in `flux-system`
- Never edit `.sops.yaml` files directly — use `sops <file>` to open, edit, and re-encrypt

## CLI Tools

All tools are pinned in `mise.toml` (short registry names, exact versions, checksums in `mise.lock`; run `mise lock` after changing versions by hand) and invoked through mise (`mise x -- <tool>`); justfile recipes and lefthook hooks already run under `mise x`.

| Tool | Purpose |
|------|---------|
| `mise` | Tool version manager — `mise install` installs everything below |
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
| `network` | Envoy Gateway, certificates, external-dns (Cloudflare and UniFi) |
| `observability` | Grafana, kube-prometheus-stack |
| `selfhosted` | Paperless-ngx, Tandoor Recipes |
| `system` | OpenEBS, kopiur/Kopia backups, Reloader |
| `system-upgrade` | Talos/Kubernetes upgrade controller (TUPR) |

## Conventions

- **YAML formatting**: All `.yaml` files must pass `yamlfmt` — runs automatically as a pre-commit hook via lefthook. Run `yamlfmt <file>` after edits.
- **Schema comments**: Files include `# yaml-language-server: $schema=...` lines for IDE validation — preserve these when editing.
- **SOPS files**: Never commit plaintext secrets. Files matching `*.sops.yaml` must stay encrypted.
- **Single node**: No node selectors, tolerations, or anti-affinity rules needed.
- **Dependency updates**: Renovate handles image tags, Helm chart versions, and Talos/Kubernetes upgrades via automated PRs.

## Available Skills

- `/k8s-view [namespace] [resource]` — Inspect live cluster state using read-only `kubectl` and `flux` commands. Use this to check HelmRelease/Kustomization health, pod status, and logs.
