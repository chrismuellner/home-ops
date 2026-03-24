---
name: k8s-view
description: Inspect live Kubernetes cluster state using read-only kubectl and flux commands
argument-hint: "[namespace] [resource-type]"
---

Inspect the live Kubernetes cluster state. Only use read-only commands (`get`, `describe`, `logs`, `top`). Never run mutating commands like `apply`, `delete`, `reconcile`, `suspend`, or `patch`.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` to determine scope:
- If a namespace is given (e.g. `media`), scope all queries with `-n <namespace>`
- If a resource type is given (e.g. `pods`, `helmrelease`, `pvc`), focus on that type
- If an app name is given, filter results to that app
- If no arguments, show a broad cluster health overview

## Step 1: Flux reconciliation status

```bash
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
```

If scoped to a namespace:
```bash
flux get helmreleases -n <namespace>
flux get kustomizations -n flux-system | grep <namespace>
```

For any resource that is not `Ready` or shows an error, get detail:
```bash
flux describe helmrelease <name> -n <namespace>
flux describe kustomization <name> -n flux-system
```

## Step 2: Pod status

```bash
kubectl get pods -n <namespace>
```

Without a namespace, focus on non-healthy pods:
```bash
kubectl get pods --all-namespaces | grep -vE 'Running|Completed'
```

For any pod not in `Running` or `Completed` state:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

## Step 3: Logs for failing containers

```bash
kubectl logs <pod-name> -n <namespace> --tail=50
kubectl logs <pod-name> -n <namespace> --previous --tail=50
```

## Step 4: Resource-specific checks (as relevant)

**PVCs:**
```bash
kubectl get pvc -n <namespace>
```

**Recent events:**
```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

**Nodes:**
```bash
kubectl get nodes
kubectl top nodes
```

**Resource usage:**
```bash
kubectl top pods -n <namespace>
```

## Step 5: Present findings

Summarize with these sections:
1. **Overall health** — all green, or list of issues
2. **Flux failures** — resource name, namespace, error message
3. **Pod issues** — pod name, namespace, reason/state
4. **Log excerpts** — relevant lines from failing containers
5. **Suggested next steps** — list commands for the user to run (do not run them yourself), e.g.:
   - `flux reconcile helmrelease <name> -n <namespace>`
   - `kubectl delete pod <name> -n <namespace>`
   - `flux suspend kustomization <name>`
