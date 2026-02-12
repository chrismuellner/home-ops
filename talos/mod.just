set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

talos_dir := justfile_dir() + '/talos'
secrets := talos_dir + '/talos-secrets.yaml'
patches := talos_dir + '/patches/controlplane.yaml'

[private]
default:
    just -l talos

[doc('Generate Talos config for a single-node cluster')]
genconfig endpoint:
    #!/usr/bin/env bash
    if [ ! -f "{{ secrets }}" ]; then
        echo "Error: talos-secrets.yaml not found at {{ secrets }}"
        echo "Generate one with: talosctl gen secrets -o {{ secrets }}"
        exit 1
    fi
    echo "Generating Talos config for endpoint {{ endpoint }}"
    talosctl gen config k8s "https://{{ endpoint }}:6443" \
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
