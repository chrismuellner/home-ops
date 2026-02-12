set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

bootstrap_dir := justfile_dir() + '/bootstrap'
kubernetes_dir := justfile_dir() + '/kubernetes'
talos_dir := justfile_dir() + '/talos'
talosconfig := talos_dir + '/talosconfig'
export TALOSCONFIG := talosconfig

controller := shell('TALOSCONFIG="$1" talosctl config info -o yaml | yq -e ".endpoints[0]"', talosconfig)
nodes := shell('TALOSCONFIG="$1" talosctl config info -o yaml | yq -e ".nodes | join(\" \")"', talosconfig)

[private]
default: check talos kube kubeconfig wait namespaces resources crds apps

[doc('Verify required binaries are available')]
check:
    #!/usr/bin/env bash
    missing=()
    for cmd in talosctl kubectl helmfile yq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing required binaries: ${missing[*]}"
        exit 1
    fi

[doc('Apply Talos configuration to all nodes')]
talos:
    #!/usr/bin/env bash
    for node in {{ nodes }}; do
        if talosctl --nodes "$node" get machinestatus &>/dev/null; then
            echo "Skipping Talos config for node $node (already configured)"
            continue
        fi
        echo "Applying Talos config to node $node"
        talosctl apply-config --insecure --nodes "$node" \
            --file "{{ talos_dir }}/controlplane.yaml"
    done

[doc('Bootstrap the Kubernetes control plane')]
kube:
    #!/usr/bin/env bash
    echo "Bootstrapping Kubernetes on {{ controller }}"
    until talosctl --nodes {{ controller }} bootstrap 2>&1 | grep -q "AlreadyExists"; do
        sleep 5
    done
    echo "Kubernetes control plane is bootstrapped"

[doc('Fetch kubeconfig from the cluster')]
kubeconfig:
    echo "Fetching kubeconfig from {{ controller }}"
    talosctl kubeconfig --nodes {{ controller }} --force

[doc('Wait for nodes to be ready')]
wait:
    #!/usr/bin/env bash
    echo "Waiting for nodes to be ready"
    until kubectl wait nodes --all --for=condition=Ready --timeout=10m 2>/dev/null; do
        echo "Waiting for nodes to register..."
        sleep 10
    done
    echo "All nodes are ready"

[doc('Create namespaces from kubernetes/apps directory structure')]
namespaces:
    #!/usr/bin/env bash
    for dir in {{ kubernetes_dir }}/apps/*/; do
        namespace=$(basename "$dir")
        echo "Ensuring namespace $namespace exists"
        kubectl create namespace "$namespace" --dry-run=client -o yaml | \
            kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -
    done

[doc('Apply bootstrap resources (SOPS age secret)')]
resources:
    echo "Creating SOPS age secret in flux-system"
    kubectl create secret generic sops-age \
        --namespace flux-system \
        --from-file=identity.agekey="{{ justfile_dir() }}/age.agekey" \
        --dry-run=client -o yaml | \
    kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -

[doc('Apply CRDs from Helm charts')]
crds:
    echo "Applying CRDs"
    helmfile --file '{{ bootstrap_dir }}/helmfile.d/00-crds.yaml' template \
        | yq 'select(.kind == "CustomResourceDefinition")' \
        | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -

[doc('Deploy core applications')]
apps:
    echo "Deploying core applications"
    helmfile --file '{{ bootstrap_dir }}/helmfile.d/01-apps.yaml' sync
