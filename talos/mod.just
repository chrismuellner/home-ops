set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

talos_dir := justfile_dir() + '/talos'
secrets := talos_dir + '/talos-secrets.yaml'
patches := talos_dir + '/patches/controlplane.yaml'
# Machine config contract (format and generated defaults), not the installed Talos version.
# Keep it pinned: bumping it can add new defaults, so diff the rendered config before changing it.
talos_contract := 'v1.14'
kubernetes_upgrade := justfile_dir() + '/kubernetes/apps/system-upgrade/tuppr/upgrades/kubernetesupgrade.yaml'

[private]
default:
    just -l talos

[doc('Generate Talos config for a single-node cluster')]
genconfig endpoint:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ secrets }}" ]; then
        echo "Error: talos-secrets.yaml not found at {{ secrets }}"
        echo "Generate one with: talosctl gen secrets -o {{ secrets }}"
        exit 1
    fi
    # Pin Kubernetes to the version tuppr manages, so genconfig never bumps it implicitly
    kubernetes_version=$(yq '.spec.kubernetes.version' "{{ kubernetes_upgrade }}")
    echo "Generating Talos config for endpoint {{ endpoint }} (contract {{ talos_contract }}, Kubernetes ${kubernetes_version})"
    talosctl gen config k8s "https://{{ endpoint }}:6443" \
        --talos-version "{{ talos_contract }}" \
        --kubernetes-version "${kubernetes_version}" \
        --with-secrets "{{ secrets }}" \
        --config-patch-control-plane @"{{ patches }}" \
        --output-types controlplane,talosconfig \
        --output "{{ talos_dir }}" \
        --with-examples=false \
        --force
    echo "Updating talosconfig with endpoint and node"
    yq -i '
        .contexts.[].endpoints = ["{{ endpoint }}"] |
        .contexts.[].nodes = ["{{ endpoint }}"]
    ' "{{ talos_dir }}/talosconfig"
    echo "Generated controlplane.yaml and talosconfig in {{ talos_dir }}"
