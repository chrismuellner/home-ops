# home ops

Single-node k3s cluster.

Thanks to k8s@home maintainers:
- https://github.com/onedr0p/flux-cluster-template
- https://github.com/bjw-s/home-ops

## Prerequisites

- Storage
    - `tv` (Sonarr) folder in `media` pvc
    - `movie` (Radarr) folder in `media` pvc

## Bootstrap

1. Install Flux
    ```sh
    kubectl apply --kustomize ./bootstrap
    ```

2. Configure RKE2 via [configuration file](https://docs.rke2.io/install/configuration#configuration-file)
    ```yaml
    cni: cilium
    disable: rke2-ingress-nginx
    ```

3. Create secret with age private key ([sealed secrets](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age))
    ```sh
    cat age.agekey |
    kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey=/dev/stdin
    ```

4. Start Flux reconciliation
    ```sh
    kubectl apply --kustomize ./clusters/lnz/config
    ```
