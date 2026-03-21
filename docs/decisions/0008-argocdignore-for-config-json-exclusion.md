---
status: superseded by [ADR-0009](0009-manifests-subdirectory-for-appset-source-path.md)
date: 2026-03-21
---

# Use .argocdignore to Exclude config.json and Restore Source Type Auto-Detection

## Context and Problem Statement

ADR-0007 introduced `source.directory.exclude: "config.json"` on both ApplicationSet source templates to prevent ArgoCD from parsing `config.json` (the Git Files Generator config, which has no `apiVersion`/`kind`) as a Kubernetes manifest. However, setting `source.directory` — even just `.exclude` — locks ArgoCD into plain directory mode for every generated Application, preventing auto-detection of Kustomize or Helm sources.

The immediate failure: `openshift-pipelines/operator/` has a `kustomization.yaml` (`kind: Component`). In forced directory mode, ArgoCD tries to apply it as a raw Kubernetes manifest, which fails because `kustomize.config.k8s.io/Component` is not a cluster CRD. The same issue affects `dev-spaces/instance/`, which also uses a `kustomization.yaml`.

## Decision Drivers

* ArgoCD must auto-detect source type (directory, Kustomize, or Helm) per component
* `config.json` must not be applied to the cluster as a Kubernetes manifest
* The Git Files Generator must continue to read `config.json` for `namespace`/`disabled` metadata
* The solution must not require per-component configuration files

## Considered Options

* `.argocdignore` at the repo root with `config.json`
* Per-component `.argocdignore` files in each `operator/` and `instance/` directory
* Move `config.json` outside the synced path (e.g., a parent or sibling directory)

## Decision Outcome

Chosen option: `.argocdignore` at the repository root, because it removes `config.json` from manifest processing globally — without setting `source.directory` on any Application — restoring ArgoCD's per-component auto-detection of Kustomize and Helm sources.

ArgoCD reads `.argocdignore` from the repository root during manifest generation and skips matching files. The Git Files Generator reads `config.json` directly from the Git API and is not affected by `.argocdignore`. The `source.directory` block is removed from both ApplicationSet source templates entirely.

### Consequences

* Good, because ArgoCD auto-detects source type per component (directory, Kustomize, Helm)
* Good, because a single root-level rule covers all current and future components
* Good, because the Git Files Generator is unaffected and continues to read `config.json`
* Bad, because the exclusion is no longer co-located with the ApplicationSet definition — contributors must know to look for `.argocdignore` at the repo root

### Confirmation

After applying the change:
- `openshift-pipelines-operator` Application syncs successfully; source type shows "Kustomize" in the ArgoCD UI
- `dev-spaces-instance` Application source type shows "Kustomize"
- Applications without a `kustomization.yaml` or `Chart.yaml` (e.g., `openshift-gitops-operator`, `openshift-gitops-instance`) remain in plain directory mode, unchanged
- No Application has `config.json` in its managed resource tree

## Pros and Cons of the Options

### `.argocdignore` at the repo root

* Good, because single file, single rule covers all components
* Good, because does not set `source.directory`, preserving source type auto-detection
* Good, because Git Files Generator is unaffected
* Bad, because less visible than an inline ApplicationSet field

### Per-component `.argocdignore` files

* Good, because exclusion is co-located with each component
* Bad, because requires a `.argocdignore` in every `operator/` and `instance/` directory
* Bad, because easy to forget when adding new components — the problem recurs per component

### Move `config.json` outside the synced path

* Bad, because the Git Files Generator pattern (`components/*/operator/config.json`) is tightly coupled to the source path; moving the file requires restructuring the generator pattern and decoupling path variables from the source path template
