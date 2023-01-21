# home ops

Single-node, k3s cluster.

## Prerequisites

- Storage
    - `tv` (Sonarr) folder in `media` pvc
    - `movie` (Radarr) folder in `media` pvc

## Bootstrap

1. Install Flux
    ```sh
    kubectl apply --kustomize ./bootstrap
    ```

2. Start Flux reconciliation
    ```sh
    kubectl apply --kustomize ./flux/config
    ```

3. Create secret with age private key ([sealed secrets](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age))
    ```sh
    cat age.agekey |
    kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey=/dev/stdin
    ```