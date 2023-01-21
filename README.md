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
