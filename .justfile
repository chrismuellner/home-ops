#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod talos "talos"

[private]
default:
    just -l

# Suspend and resume all helmreleases that are not in ready state
reconcile-helmreleases:
    flux get helmreleases -A --no-header --status-selector ready=false | awk '{print $1, $2}' | while read ns name; do \
        echo "Reconciling helmrelease $ns/$name ..."; \
        flux suspend helmrelease -n "$ns" "$name"; \
        flux resume helmrelease -n "$ns" "$name"; \
    done

# Suspend and resume all kustomizations that are not in ready state
reconcile-kustomizations:
    flux get kustomizations -A --no-header --status-selector ready=false | awk '{print $1, $2}' | while read ns name; do \
        echo "Reconciling kustomization $ns/$name ..."; \
        flux suspend kustomization -n "$ns" "$name"; \
        flux resume kustomization -n "$ns" "$name"; \
    done
